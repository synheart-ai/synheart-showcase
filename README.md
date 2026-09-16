# Synheart Showcase

Synheart Showcase is a collection of applications that demonstrate what can be built with the Synheart Human State Interface (HSI).

Each project explores a practical way for software to respond to consented, privacy-aware human-state context while keeping the user in control of the experience.

## Showcases

### [Resona](resona)

**Music that understands the moment.**

Resona is an adaptive music experience built with Flutter and Synheart. It receives supported wearable signals, computes HSI locally, and uses trustworthy state updates to offer subtle soundtrack recommendations.

Resona demonstrates:

- Apple Health and Health Connect wearable sources
- Direct Bluetooth heart-rate monitor support
- On-device HSI computation with confidence-aware experience rules
- User-controlled adaptive music recommendations
- Background audio and iOS Live Activities
- A privacy-first interface that avoids exposing raw physiological data

See the [Resona guide](resona/README.md) for architecture, setup, wearable support, and development instructions.

## Repository structure

```text
synheart-showcase/
└── resona/    Flutter adaptive-music showcase
```

Each showcase is self-contained and has its own dependencies and setup guide. Proprietary Synheart Runtime binaries are not stored in this repository; authorized developers install the required artifacts with the Synheart CLI.

## Responsible use

Synheart showcases are examples of adaptive software design. They should be built around meaningful consent, data minimization, transparent recommendations, and user choice.

**These showcases are wellness and developer demonstrations, not medical software. They do not diagnose, treat, cure, or prevent any disease or medical condition and must not be used for clinical or safety-critical decisions.**

## Contributing

Keep each showcase focused, reproducible, and understandable on its own. Do not commit credentials, provisioning profiles, user data, generated build output, or proprietary runtime artifacts.
