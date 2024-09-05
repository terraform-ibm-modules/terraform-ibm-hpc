import json


def modifycontentforcustomimagebuilder(filePath):
    with open(filePath, "r") as f:
        data = json.load(f)
    if "hostProviders" in filePath:
        jsonToString = json.dumps(data).replace("ibmcloudhpc", "ibmcloudgen2")
        stringToJson = json.loads(jsonToString)
        with open(filePath, "w") as f:
            data = json.dumps(stringToJson, indent=4)
            f.write(data)
    if "ibmcloudgen2_config" in filePath:
        apiEndPoints = data["ApiEndPoints"]
        apiEndPoints["us-south"] = "https://us-south.iaas.cloud.ibm.com/v1"
        apiEndPoints["us-east"] = "https://us-east.iaas.cloud.ibm.com/v1"
        apiEndPoints["eu-de"] = "https://eu-de.iaas.cloud.ibm.com/v1"
        with open(filePath, "w") as f:
            data = json.dumps(data, indent=4)
            f.write(data)


hostProvidersFilePath = "/opt/ibm/lsf/conf/resource_connector/hostProviders.json"
configFilePath = (
    "/opt/ibm/lsf/conf/resource_connector/ibmcloudgen2/conf/ibmcloudgen2_config.json"
)
modifycontentforcustomimagebuilder(hostProvidersFilePath)
modifycontentforcustomimagebuilder(configFilePath)
