*** Settings ***
Documentation    An Assistant that asks the user to upload two images, then runs
...    the Base64.ai's signature matching algorithm over them in order to see what
...    signatures are found there and if they match or not.
...    The result is shown in the Assistant dialog UI.

Library    Collections
Library    RPA.Assistant
Library    RPA.DocumentAI.Base64AI
Library    RPA.FileSystem
Library    RPA.Robocorp.Vault


*** Variables ***
${SUPPORTED_IMAGES}    jpg,jpeg,png
${DEFAULT_THRESHOLD}    0.8
${TITLE}    Signature Analyzer


*** Keywords ***
Collect And Check Signatures
    [Documentation]    Render a UI that asks for two images and optionally threshold
    ...    values. Adds a button that checks signatures and displays found results.

    Clear Dialog

    Add Heading    Validate signature from image
    ${source_dir} =    Absolute Path    devdata${/}signatures
    Add File Input    name=query_image    label=Query Image (e.g. contract)
    ...    source=${source_dir}    file_type=${SUPPORTED_IMAGES}
    Add File Input    name=reference_image    label=Reference Image (e.g. passport)
    ...    source=${source_dir}    file_type=${SUPPORTED_IMAGES}

    Add Text    Optionally set custom thresholds (default: 0.8)
    Add Text  Confidence Threshold
    Add Slider  confidence_threshold  slider_min=0.0  slider_max=1.0
    ...    steps=10  default=0.8
    Add Text  Similarity Threshold
    Add Slider  similarity_threshold  slider_min=0.0  slider_max=1.0
    ...    steps=10  default=0.8

    Add Next Ui Button  Check signatures  Check Signatures

Check Signatures
    [Arguments]  ${result}

    Log To Console    Result: ${result}

    # Validate input data, if it doesn't contain both required pictures we
    # report the error to the user.
    TRY
        Dictionary Should Contain Key    ${result}    query_image
        ...    msg=A query image must be provided
        Dictionary Should Contain Key    ${result}    reference_image
        ...    msg=A reference image must be provided
    EXCEPT  AS  ${error}
        Report Error    ${error}
        RETURN
    END

    ${confidence_threshold} =    Pop From Dictionary    ${result}
    ...    confidence_threshold    default=${DEFAULT_THRESHOLD}
    ${similarity_threshold} =    Pop From Dictionary    ${result}
    ...    similarity_threshold    default=${DEFAULT_THRESHOLD}
    ${confidence_threshold} =    Convert To Number    ${confidence_threshold}
    ${similarity_threshold} =    Convert To Number    ${similarity_threshold}

    Analyze Signatures  ${result}[query_image]    ${result}[reference_image]
    ...    ${confidence_threshold}   ${similarity_threshold}

Analyze Signatures
    [Arguments]    ${qry_img}     ${ref_img}     ${conf_thres}    ${sim_thres}

    Clear Dialog
    Add Heading  Analyzing images, please wait...
    Refresh Dialog

    # Call the Base64 API to check if the signatures match. Use TRY-EXCEPT to handle
    #  the API errors and display them.
    TRY
        ${sigs} =   Get Matching Signatures     ${ref_img}[${0}]    ${qry_img}[${0}]
    EXCEPT  AS  ${err_msg}
        Report Error  ${err_msg}
        RETURN
    END

    Log Dictionary    ${sigs}  # the raw output with results
    &{matches} =   Filter Matching Signatures      ${sigs}
    ...    confidence_threshold=${conf_thres}    similarity_threshold=${sim_thres / 2}
    Log Dictionary    ${matches}  # filtered accepted similar enough signatures

    @{ref_sigs} =    Get Dictionary Keys    ${matches}
    IF    ${ref_sigs}
        # Get signature image crop from the first found reference.
        ${ref_sig} =    Set Variable    ${ref_sigs}[${0}]
        ${ref_path} =    Get Signature Image    ${sigs}    index=${ref_sig}[${0}]
        ...    reference=${True}  # very important to set when retrieving references

        # Now get the most similar to reference found signature in the queried image.
        @{qry_sigs} =    Get From Dictionary    ${matches}    ${ref_sig}
        &{qry_sig} =    Set Variable    ${qry_sigs}[${0}]
        ${qry_path} =    Get Signature Image    ${sigs}    index=${qry_sig}[index]

        # Check if signatures are similar enough and retrieve the confidence as well.
        ${status} =    Run Keyword And Return Status    Should Be True
        ...    ${qry_sig}[similarity] >= ${sim_thres}
        ${qry_conf} =    Set Variable    ${sigs}[query][${qry_sig}[index]][confidence]
        ${ref_conf} =    Set Variable
        ...    ${sigs}[reference][${ref_sig}[${0}]][confidence]

        Display Similar Signatures    ${qry_path}    ${qry_conf}
        ...    ${ref_path}    ${ref_conf}    ${status}    ${qry_sig}[similarity]
    ELSE
        Report No Similar Signatures
    END

Display Similar Signatures
    [Documentation]    Show similar signatures as image crops for manual inspection.
    [Arguments]    ${qry_path}  ${qry_conf}  ${ref_path}  ${ref_conf}
    ...    ${status}  ${similarity}

    Clear Dialog
    IF    ${status}
        Add Icon    Success
        Add Heading    Signatures match
    ELSE
        Add Icon    Warning
        Add Heading    Signatures don't match
    END

    Add Heading    Similarity: ${similarity * 100}%

    Add Text    The signature to check (confidence ${qry_conf * 100}%):
    Add Image    ${qry_path}
    Add Text    The trusted signature to compare with (confidence ${ref_conf * 100}%):
    Add Image    ${ref_path}

    Add Button  Retry  Retry Dialog

    Refresh Dialog

Report No Similar Signatures
    [Documentation]    Show that the signatures are not found nor matching at all.

    Clear Dialog
    Add Icon    Failure
    Add Heading    No signatures recognized or they are too different
    Add Text    Lower the confidence and similarity thresholds, then try again!

    Add Button  Retry      Retry Dialog
    Refresh Dialog

Report Error
    [Documentation]  Report an error in the UI.

    [Arguments]  ${error_message}

    Clear Dialog
    Add Icon    Failure
    Add Heading    Got error:
    Add Text  ${error_message}
    Add Button  Retry      Retry Dialog
    Refresh Dialog

Retry Dialog
    [Documentation]  Goes back to the main menu.

    Collect And Check Signatures
    Refresh Dialog


*** Tasks ***
Check Signature Matching In Images
    [Documentation]    Start an Assistant loop for checking similar signatures found in
    ...    the provided images. Ability to customize acceptance criteria (confidence
    ...    and similarity thresholds).

    ${secret} =     Get Secret    Base64
    Set Authorization    ${secret}[email]    ${secret}[api-key]

    Collect And Check Signatures
    Run Dialog  height=750  title=${TITLE}
