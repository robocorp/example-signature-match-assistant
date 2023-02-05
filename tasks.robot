*** Settings ***
Documentation       An Assistant that asks user to upload two files,
...                 and then runs Base64.ai signature matching on them.
...                 The result is shown in the Assistant Dialog UI.        

Library    RPA.Dialogs
Resource   resources/base64.robot

*** Variables ***
${THRESHOLD}    0.8

*** Tasks ***
Signature match
    # Get files with two dialogs
    ${file1_path}=    Collect file from user    a new document with a signature    1
    ${file2_path}=    Collect file from user    an old document with reference signature    2

    ${dialog}=    Show progress dialog
    # Call API and parse results to more digestable format
    ${sig_path_ref}    ${sig_path_query}    ${sig_conf_ref}    ${sig_conf_query}   ${score}
    ...    Match signatures with Base64    ${file1_path}    ${file2_path}
    Close progress dialog    ${dialog}

    Show results dialog    ${sig_path_ref}    ${sig_path_query}    ${sig_conf_ref}    ${sig_conf_query}   ${score}

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