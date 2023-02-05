import base64
from robot.api import logger

def image_to_base64(filepath):
    with open(filepath, "rb") as img_file:
        base64string = base64.b64encode(img_file.read())

    return base64string.decode("utf-8")

def base64_to_image(base64string, filepath):
    with open(filepath, "wb") as img_file:
        img_file.write(base64.b64decode(base64string))
  
def read_matching_response(response):

    logger.info(f"Found {len(response['reference'])} signatures from REFERENCE image, top confidence is {str(response['reference'][0]['confidence'])}")
    logger.info(f"Found {len(response['query'])} signatures from QUERY image, top confidence is {str(response['query'][0]['confidence'])}")

    # Find highest similiarity and return it's index.
    max = 0
    index = 0
    for i in range(1,len(response['query'][0]['similarities'])):
        if response['query'][0]['similarities'][i] > max:
            max = response['query'][0]['similarities'][i]
            index = i

    logger.info(f"Index of the maximum value is : {index}")
    logger.info(f"Match score for it is: {response['query'][0]['similarities'][index]}")

    path_querysig = "query_image.png"
    path_referencesig = "reference_image.png"

    base64_to_image(response['query'][0]['image'].split(',')[1], path_querysig)
    base64_to_image(response['reference'][index]['image'].split(',')[1], path_referencesig)

    return path_referencesig, path_querysig, response['reference'][0]['confidence'], response['query'][0]['confidence'], response['query'][0]['similarities'][index]
