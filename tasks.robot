*** Settings ***
Documentation       An Assistant that asks user to upload two files,
...                 and then runs Base64.ai signature matching on them.
...                 The result is shown in the Assistant Dialog UI.

Library    Collections
Library    RPA.Dialogs
Library    RPA.DocumentAI.Base64AI
Library    RPA.Robocorp.Vault

Resource   resources/base64.robot

*** Variables ***
${THRESHOLD}    0.6

*** Tasks ***
Signature match assistant
    # Get files with two dialogs
    ${file1_path}=    Collect file from user    a new document with a signature    1
    ${file2_path}=    Collect file from user    an old document with reference signature    2

    ${dialog}=    Show progress dialog
    # Call API and parse results to more digestable format
    ${sig_path_ref}    ${sig_path_query}    ${sig_conf_ref}    ${sig_conf_query}   ${score}
    ...    Match signatures with Base64    ${file1_path}    ${file2_path}
    Close progress dialog    ${dialog}

    Show results dialog    ${sig_path_ref}    ${sig_path_query}    ${sig_conf_ref}    ${sig_conf_query}   ${score}

Match Signatures With Library
    ${secret} =     Get Secret    Base64
    Set Authorization    ${secret}[email]    ${secret}[api-key]

    ${query_image} =    Collect file from user    a new document with a signature    1
    ${ref_image} =    Collect file from user    an old document with reference signature    2

    ${dialog}=    Show progress dialog
    ${sigs} =   Get Matching Signatures     ${ref_image}    ${query_image}
    Log Dictionary    ${sigs}
    &{matches} =   Filter Matching Signatures      ${sigs}    confidence_threshold=${THRESHOLD}    similarity_threshold=${THRESHOLD}
    Close progress dialog    ${dialog}
    Log Dictionary    ${matches}

    @{ref_sigs} =    Get Dictionary Keys    ${matches}
    IF    ${ref_sigs}
        @{qry_sigs} =    Get From Dictionary    ${matches}    ${ref_sigs}[${0}]
        ${path} =    Get Signature Image    ${sigs}    index=${qry_sigs}[${0}][index]
        Log To Console    Similar signature: ${path}
    ELSE
        Log To Console    No similar signature found
    END



*** Keywords ***
Collect file from user
    [Documentation]    Opens RPA.Dialogs dialogue asking user to upload a file
    [Arguments]     ${text}    ${stepnr}

    Add heading    Match signatures between two documents. Step ${stepnr}/2
    Add file input
    ...    label=Browse and upload ${text}
    ...    name=fileupload
    ...    file_type=Image files (*.png;*.jpg;*.jpeg)
    ...    destination=${OUTPUT_DIR}
    ${response}=    Run dialog
    RETURN    ${response.fileupload}[0]

Show results dialog
    [Documentation]   Show results
    [Arguments]        ${sig_path_ref}    ${sig_path_query}    ${sig_conf_ref}    ${sig_conf_query}   ${score}

    Clear elements
    IF   ${score} > ${THRESHOLD}
        Add heading    READY: Signatures are a match!
    ELSE
        Add heading    ALERT: Signatures don't match!
    END
    Add text       Match score between query and reference: ${score}
    Add image      ${sig_path_ref}
    Add text       Reference signature confidence: ${sig_conf_ref}    size=small
    Add image      ${sig_path_query}
    Add text       Query signature confidence: ${sig_conf_query}    size=small
    Add submit buttons    buttons=Close
    Run dialog

Show progress dialog
    Clear elements
    Add heading    Processing signature matching on two files...
    ${dialog}=    Show dialog
    [Return]    ${dialog}

Close progress dialog
    [Arguments]    ${dialog}
    Close dialog    ${dialog}
