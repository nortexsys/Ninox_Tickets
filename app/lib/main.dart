import 'package:flutter/material.dart';

import 'app/dependencies.dart';
import 'app/paperdrop_app.dart';
import 'legal/pdfium_notices.dart';

void main() {
  // The PDFium binary this application links is not covered by Flutter's own
  // notices (NFR-LIC-001): its licences ship as assets and are registered here,
  // before the first frame, so that Flutter's licence page shows them.
  registerPdfiumLicences();
  // The device answers whether it already holds a destination, and that answer is
  // what the shell opens on: the wizard on a first run, capture afterwards
  // (design §10 of `implement-setup-wizard`, task 3.5). The question is the
  // application's own composition, which is why it is handed in here and not
  // defaulted inside the shell.
  runApp(PaperdropApp(hasDestination: deviceHasDestination));
}
