*** Settings ***
Documentation    An Assistant that asks the user to upload two images, then runs
...    the Base64.ai's signature matching algorithm over them in order to see what
...    signatures are found there and if they match or not.
...    The result is shown in the Assistant dialog UI.

Library    Collections
Library    RPA.Assistant
Library    RPA.DocumentAI.Base64AI
Library    RPA.Robocorp.Vault


*** Variables ***
${SUPPORTED_IMAGES}    jpg,jpeg,png
${DEFAULT_THRESHOLD}    0.8


*** Keywords ***
Collect Images From User
    [Documentation]    Render a UI that asks for two images and optional threshold
    ...    values.

    Clear Dialog
    Add Heading    Validate signature from image

    Add File Input    name=query_image    label=Query Image (eg. contract)
    ...    source=devdata    destination=${OUTPUT_DIR}    file_type=${SUPPORTED_IMAGES}
    Add File Input    name=reference_image    label=Reference Image (eg. passport)
    ...    source=devdata    destination=${OUTPUT_DIR}    file_type=${SUPPORTED_IMAGES}

    Add text    Optionally set custom thresholds (default: 0.8)
    Add Text Input    name=confidence_threshold    label=Confidence Threshold
    ...    placeholder=0.0-1.0 (recognize signatures)
    Add Text Input    name=similarity_threshold    label=Similarity Threshold
    ...    placeholder=0.0-1.0 (alike signatures)

    &{result} =    Ask User
    Log To Console    Result: ${result}
    IF    "${result}[submit]" == "Close"    Pass Execution    Aborted

    # Validate input data and provide defaults for the optional threshold values.
    Dictionary Should Contain Key    ${result}    reference_image
    ...    msg=A reference image must be provided
    Dictionary Should Contain Key    ${result}    query_image
    ...    msg=A query image must be provided

    ${confidence_threshold} =    Pop From Dictionary    ${result}
    ...    confidence_threshold    default=${DEFAULT_THRESHOLD}
    ${similarity_threshold} =    Pop From Dictionary    ${result}
    ...    similarity_threshold    default=${DEFAULT_THRESHOLD}
    ${confidence_threshold} =    Convert To Number    ${confidence_threshold}
    ${similarity_threshold} =    Convert To Number    ${similarity_threshold}

    RETURN    ${result}[query_image]    ${result}[reference_image]
    ...    ${confidence_threshold}    ${similarity_threshold}

Ask For Retry
    [Documentation]    Continue or exit the loop of signature verification process.

    Add submit buttons    buttons=Retry,Exit    default=Exit
    &{result} =    Run Dialog
    ${retry} =    Run Keyword And Return Status    Should Be Equal As Strings
    ...    ${result}[submit]    Retry
    RETURN    ${retry}

Display Similar Signatures
    [Documentation]    Show similar signatures as image crops for manual inspection.
    [Arguments]    ${qry_path}    ${ref_path}    ${status}

    Clear Dialog
    IF    ${status}
        Add Icon    Success
        Add Heading    Signatures match
    ELSE
        Add Icon    Warning
        Add Heading    Signatures don't match
    END

    Add text    The signature to check:
    Add Image    ${qry_path}
    Add text    The trusted signature to compare with:
    Add Image    ${ref_path}

    ${retry} =    Ask For Retry
    RETURN    ${retry}

Report No Similar Signatures
    [Documentation]    Show that the signatures are not found nor matching at all.

    Clear Dialog
    Add Icon    Failure
    Add Heading    No signatures recognized or they are too different
    Add Text    Lower the confidence and similarity thresholds, then try again!

    ${retry} =    Ask For Retry
    RETURN    ${retry}

Collect And Check Signatures
    [Documentation]    Obtain two images and check for similar signatures with
    ...    Base64.ai. Display the found signatures for further manual inspection.

    ${qry_img}  ${ref_img}  ${conf_thres}  ${sim_thres} =    Collect Images From User
    Log To Console    Analyzing images, please wait...
    ${sigs} =   Get Matching Signatures     ${ref_img}[${0}]    ${qry_img}[${0}]
    Log Dictionary    ${sigs}  # the raw output with results
    &{matches} =   Filter Matching Signatures      ${sigs}
    ...    confidence_threshold=${conf_thres}    similarity_threshold=${sim_thres / 2}
    Log Dictionary    ${matches}  # filtered accepted similar enough signatures

    @{ref_sigs} =    Get Dictionary Keys    ${matches}
    IF    ${ref_sigs}
        # Get signature image crop from the first found reference.
        ${ref_sig} =    Set Variable    ${ref_sigs}[${0}]
        ${ref_path} =    Get Signature Image    ${sigs}    index=${ref_sig}[${0}]
        ...    reference=${True}  # very important to tell when retrieving references

        # Now get the most similar to reference found signature in the queried image.
        @{qry_sigs} =    Get From Dictionary    ${matches}    ${ref_sig}
        &{qry_sig} =    Set Variable    ${qry_sigs}[${0}]
        ${qry_path} =    Get Signature Image    ${sigs}    index=${qry_sig}[index]

        ${status} =    Run Keyword And Return Status    Should Be True
        ...    ${qry_sig}[similarity] >= ${sim_thres}
        ${retry} =    Display Similar Signatures    ${qry_path}    ${ref_path}
        ...    ${status}
    ELSE
        ${retry} =    Report No Similar Signatures
    END

    RETURN    ${retry}


*** Tasks ***
Check Signature Matching In Images
    [Documentation]    Start an Assistant loop for checking similar signatures found in
    ...    the provided images. Ability to customize acceptance criteria (confidence
    ...    and similarity thresholds).

    ${secret} =     Get Secret    Base64
    Set Authorization    ${secret}[email]    ${secret}[api-key]

    WHILE    ${True}    limit=NONE
        ${retry} =    Collect And Check Signatures
        IF    ${retry} is ${False}    BREAK
    END
