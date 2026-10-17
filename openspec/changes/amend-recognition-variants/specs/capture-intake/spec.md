## MODIFIED Requirements

### Requirement: platform-document-scanner

Camera capture SHALL use the platform's document scanner — ML Kit Document Scanner
on Android, VisionKit document camera on iOS — and SHALL never present a raw camera
view. Edge detection, perspective correction, contrast enhancement and multi-page
chaining SHALL come from the platform, and the prototype's pre-processing stage
SHALL NOT be ported.

A **recognition variant** is an in-memory copy of an image, created for the sole
purpose of one extra recognition reading. A recognition variant SHALL never be
written to storage, SHALL never be attached, SHALL never be shown to the user, and
SHALL never be used as the image of record; the platform scanner's output SHALL
remain the only image that is stored and attached. A recognition variant SHALL NOT
include perspective correction, binarisation, cropping, deskew or any re-encoding.
[Origen: Funcional §4.1 FR-CAP-002; PDR §7.1; ADR-006; DEC-017]

#### Scenario: the platform crops and deskews the capture

- GIVEN a photographed receipt
- WHEN the capture reaches extraction
- THEN it has been cropped and deskewed by the platform scanner

#### Scenario: the app carries no pre-processing of its own

- GIVEN the application's own code
- WHEN it is inspected for image processing
- THEN it contains no perspective-correction, no binarisation and no re-encoding routine
- AND the only place that decodes an image is the single recognition-variant decoder
- AND no stage re-enhances an image for storage, attachment or display

#### Scenario: a recognition variant is never persisted

- GIVEN a recognition variant created in memory for one extra recognition reading
- WHEN that reading completes
- THEN the variant is discarded
- AND it was at no point written to storage, attached or shown to the user

#### Scenario: the attached image is the scanner's output, byte for byte

- GIVEN a photograph read through one or more recognition variants
- WHEN the record is saved
- THEN the attached image is the platform scanner's output
- AND its SHA-256 equals the SHA-256 of that output as produced before any
  recognition variant was created
