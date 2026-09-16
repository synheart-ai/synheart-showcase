import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

private let resonaLime = Color(red: 185 / 255, green: 1, blue: 40 / 255)

@main
struct ResonaLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    ResonaLiveActivityWidget()
  }
}

struct ResonaLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ResonaActivityAttributes.self) { context in
      HStack(spacing: 14) {
        ResonaStateImage(name: context.state.stateImage, size: 46)

        VStack(alignment: .leading, spacing: 3) {
          Text(context.state.title)
            .font(.headline)
            .lineLimit(1)
          Text("\(context.state.state) · \(context.state.message)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)
        AnimatedWaveform(isPlaying: context.state.isPlaying, size: 28)
      }
      .padding()
      .activityBackgroundTint(Color.black.opacity(0.92))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          ResonaStateImage(name: context.state.stateImage, size: 38)
        }
        DynamicIslandExpandedRegion(.trailing) {
          AnimatedWaveform(isPlaying: context.state.isPlaying, size: 30)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(context.state.title)
              .font(.headline)
              .lineLimit(1)
            Text(context.state.artist)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 8) {
            Text(context.state.state.uppercased())
              .font(.caption2.weight(.bold))
              .tracking(1)
              .foregroundStyle(resonaLime)
            Text(context.state.message)
              .font(.caption.weight(.medium))
              .lineLimit(1)
            Spacer()
          }
          .padding(.top, 4)
        }
      } compactLeading: {
        ResonaStateImage(name: context.state.stateImage, size: 24)
      } compactTrailing: {
        AnimatedWaveform(isPlaying: context.state.isPlaying, size: 23)
      } minimal: {
        ResonaStateImage(name: context.state.stateImage, size: 24)
      }
      .widgetURL(URL(string: "resona://player"))
      .keylineTint(resonaLime.opacity(0.8))
    }
  }
}

private struct ResonaStateImage: View {
  let name: String
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle().fill(Color.white.opacity(0.10))
      Image(name)
        .resizable()
        .scaledToFit()
        .padding(2)
    }
    .frame(width: size, height: size)
  }
}

private struct AnimatedWaveform: View {
  let isPlaying: Bool
  let size: CGFloat

  @ViewBuilder
  var body: some View {
    if isPlaying {
      TimelineView(.animation(minimumInterval: 0.16)) { timeline in
        WaveformBars(
          phase: timeline.date.timeIntervalSinceReferenceDate * 6,
          size: size
        )
      }
      .frame(width: size, height: size)
    } else {
      Image(systemName: "pause.fill")
        .font(.system(size: size * 0.48, weight: .bold))
        .foregroundStyle(resonaLime)
        .frame(width: size, height: size)
    }
  }
}

private struct WaveformBars: View {
  let phase: Double
  let size: CGFloat

  var body: some View {
    HStack(alignment: .center, spacing: size * 0.08) {
      ForEach(0..<4, id: \.self) { index in
        let pulse = abs(sin(phase + Double(index) * 0.92))
        Capsule()
          .fill(resonaLime)
          .frame(
            width: max(2, size * 0.09),
            height: size * (0.26 + 0.56 * pulse)
          )
      }
    }
    .frame(width: size, height: size)
  }
}
