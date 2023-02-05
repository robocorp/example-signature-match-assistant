*** Settings ***
Library    helper.py
Library    RPA.Robocorp.Vault
Library    RPA.HTTP
Library    String
Library    RPA.FileSystem

*** Keywords ***
Match signatures with Base64
    [Arguments]    ${file1}    ${file2}

    ${BASE64_API_URL}=     Set Variable    https://base64.ai/api/signature/recognize

    # Take only file extension
    # There is no error handling for wrong extensions here, as
    # the upload dialog takes care of that.
    ${file1ext}=    Get File Extension    ${file1}
    ${file2ext}=    Get File Extension    ${file2}

    # Currently supports only jpegs and pngs, ignoring the rest!
    IF    "${file1ext}" == ".jpg" or "${file1ext}" == ".jpeg"
        ${type1}=    Set Variable    image/jpeg
    ELSE IF    "${file1ext}" == ".png"
        ${type1}=    Set Variable    image/png
    END

    # Currently supports only jpegs and pngs, ignoring the rest!
    IF    "${file2ext}" == ".jpg" or "${file2ext}" == ".jpeg"
        ${type2}=    Set Variable    image/jpeg
    ELSE IF    "${file2ext}" == ".png"
        ${type2}=    Set Variable    image/png
    END

    # Convert picture to base64 encoding using included Python method from convert.py
    ${base64string1}=    Image To Base64    ${file1}
    ${base64string2}=    Image To Base64    ${file2}

    # Create Base64.ai authentication headers
    ${base64_secret}=    Get Secret    Base64
    ${headers}=    Create Dictionary
    ...    Authorization=${base64_secret}[auth-header]

    # Create Base64.ai API JSON payload
    ${string1}=    Catenate    SEPARATOR=    data:    ${type1}    ;base64,    ${base64string1}
    ${string2}=    Catenate    SEPARATOR=    data:    ${type2}    ;base64,    ${base64string2}

    ${body}=    Create Dictionary
    ...    referenceImage=${string2}
    ...    queryImage=${string1}

    # Post to Base64.ai API.
    ${response}=    POST
    ...    url=${BASE64_API_URL}
    ...    headers=${headers}
    ...    json=${body}
    
    ${sig_path_ref}    ${sig_path_query}    ${sig_conf_ref}    ${sig_conf_query}    ${score}     Read Matching Response    ${response.json()}

    [Return]    ${sig_path_ref}    ${sig_path_query}    ${sig_conf_ref}    ${sig_conf_query}   ${score}