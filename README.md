# Find similar signatures in image documents

This bot spawns an Assistant UI which asks for two images that may contain signatures.
Then it checks for and displays similar ones, including their confidence score. (levels
can be adjusted)

The two requested images are the following:
- **Query**: The image that contains signatures you want to test. (like a contract or
  check -- eg. [signature-check](devdata/signature-check.png))
- **Reference**: A document you trust to have a valid signature belonging to the entity
  you're checking against. (like a passport or driver license -- eg.
  [signature-license](devdata/signature-license.jpg))

## Tasks

### `Check Signature Matching In Images`

Start an Assistant loop for checking similar signatures found in the provided images.
Ability to customize acceptance criteria (confidence and similarity thresholds).

## Remarks

This robot uses the [`RPA.DocumentAI.Base64AI`]([ds](https://robocorp.com/docs/libraries/rpa-framework/rpa-documentai-base64ai))
library and this requires a 3rd-party service and credentials (Vault) configuration.
