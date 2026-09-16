const ALLOWED_KEYS = new Set([
  "music/sub-clair-background-music-591220.mp3",
  "music/maksymmalko-background-music-594961.mp3",
  "music/soundsurfer-stylish-music-587940.mp3",
  "music/high-arpmedia-background-music-577823.mp3",
  "music/kontraa-no-sleep-hiphop-music-473847.mp3",
  "music/alex-morgan-smooth-jazz-lounge-relaxing-evening-537465.mp3",
  "music/lofi-music-selection.mp3",
  "music/instrumental-lofi-hip-hop.mp3",
  "music/prettyjohn1-background-background-music-581651.mp3",
  "music/vibemode-background-music-581673.mp3",
  "art/0d8a1ea2-60df-4aed-a0c8-495a6e8b60d6.png",
  "art/1b36806b-fadc-465b-a41e-42e68d25d3a1.png",
  "art/2a7f2586-5cad-4ad3-91c7-017a86763a09.png",
  "art/694319cd-c689-452d-8073-a60ef5b7d293.png",
  "art/8cc0a063-b22c-4314-ada9-9e602eb3b58e.png",
  "art/8d1aa432-aeaa-41cb-81a8-159153d15146.png",
  "art/93a28e61-fe48-4de3-9720-dc3c491d04db.png",
  "art/bf9f265c-92cb-4046-ba43-7205b912cb87.png",
  "art/c7c871ce-1fff-4b6c-9a56-a895d8fc6688.png",
  "art/ec574bbd-4a52-46c8-a210-9455c4adf47c.png",
]);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Allow-Headers": "Range, If-None-Match, If-Modified-Since",
  "Access-Control-Expose-Headers":
    "Accept-Ranges, Content-Length, Content-Range, ETag",
  "Access-Control-Max-Age": "86400",
};

function withCommonHeaders(headers = new Headers()): Headers {
  for (const [name, value] of Object.entries(corsHeaders)) {
    headers.set(name, value);
  }
  headers.set("Accept-Ranges", "bytes");
  headers.set("Cache-Control", "public, max-age=86400");
  headers.set("Cross-Origin-Resource-Policy", "cross-origin");
  headers.set("X-Content-Type-Options", "nosniff");
  return headers;
}

function parseRange(
  value: string | null,
  size: number,
): { offset: number; length: number } | null | "invalid" {
  if (value === null) return null;

  const match = /^bytes=(\d*)-(\d*)$/.exec(value.trim());
  if (match === null || (match[1] === "" && match[2] === "")) {
    return "invalid";
  }

  let offset: number;
  let end: number;
  if (match[1] === "") {
    const suffixLength = Number(match[2]);
    if (!Number.isSafeInteger(suffixLength) || suffixLength <= 0) {
      return "invalid";
    }
    offset = Math.max(0, size - suffixLength);
    end = size - 1;
  } else {
    offset = Number(match[1]);
    end = match[2] === "" ? size - 1 : Number(match[2]);
    if (
      !Number.isSafeInteger(offset) ||
      !Number.isSafeInteger(end) ||
      offset < 0 ||
      offset >= size ||
      end < offset
    ) {
      return "invalid";
    }
    end = Math.min(end, size - 1);
  }

  return { offset, length: end - offset + 1 };
}

function errorResponse(message: string, status: number): Response {
  return Response.json(
    { error: message },
    { status, headers: withCommonHeaders() },
  );
}

export default {
  async fetch(request, env): Promise<Response> {
    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: withCommonHeaders() });
      }

      const url = new URL(request.url);
      if (url.pathname === "/health") {
        return Response.json(
          { service: "resona-media", status: "ok" },
          { headers: withCommonHeaders() },
        );
      }

      if (request.method !== "GET" && request.method !== "HEAD") {
        const headers = withCommonHeaders();
        headers.set("Allow", "GET, HEAD, OPTIONS");
        return Response.json({ error: "Method not allowed" }, { status: 405, headers });
      }

      let key: string;
      try {
        key = decodeURIComponent(url.pathname.slice(1));
      } catch {
        return errorResponse("Invalid object path", 400);
      }

      if (!ALLOWED_KEYS.has(key)) {
        return errorResponse("Not found", 404);
      }

      const metadata = await env.MEDIA.head(key);
      if (metadata === null) {
        return errorResponse("Not found", 404);
      }

      const headers = withCommonHeaders();
      metadata.writeHttpMetadata(headers);
      headers.set("ETag", metadata.httpEtag);

      if (request.method === "HEAD") {
        headers.set("Content-Length", metadata.size.toString());
        return new Response(null, { status: 200, headers });
      }

      const requestedRange = parseRange(request.headers.get("Range"), metadata.size);
      if (requestedRange === "invalid") {
        headers.set("Content-Range", `bytes */${metadata.size}`);
        return new Response(null, { status: 416, headers });
      }

      const object = await env.MEDIA.get(
        key,
        requestedRange === null ? undefined : { range: requestedRange },
      );
      if (object === null) {
        return errorResponse("Not found", 404);
      }

      object.writeHttpMetadata(headers);
      headers.set("ETag", object.httpEtag);
      if (requestedRange !== null) {
        const end = requestedRange.offset + requestedRange.length - 1;
        headers.set(
          "Content-Range",
          `bytes ${requestedRange.offset}-${end}/${metadata.size}`,
        );
        headers.set("Content-Length", requestedRange.length.toString());
      } else {
        headers.set("Content-Length", metadata.size.toString());
      }

      console.log(
        JSON.stringify({
          message: "music served",
          key,
          partial: requestedRange !== null,
        }),
      );
      return new Response(object.body, {
        status: requestedRange === null ? 200 : 206,
        headers,
      });
    } catch (error) {
      console.error(
        JSON.stringify({
          message: "media request failed",
          error: error instanceof Error ? error.message : String(error),
        }),
      );
      return errorResponse("Internal server error", 500);
    }
  },
} satisfies ExportedHandler<Env>;
