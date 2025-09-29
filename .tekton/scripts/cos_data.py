import glob
import os
import sys

import ibm_boto3
from ibm_botocore.client import ClientError, Config


class DownloadFromCOS:
    def upload_file(self, bucket_name, file_path, filename):
        print(f"-- working on file {filename}")
        try:
            self.client.upload_file(
                Filename=filename, Bucket=bucket_name, Key=file_path
            )
            print(f"--- {filename} successfully uploaded in {file_path}!")
        except ClientError as be:
            print(f"[CLIENT ERROR]: {be}\n")
            self.return_code += 1
        except Exception as e:
            print(f"[CLIENT ERROR] Unable to upload file to COS: {e}")
            self.return_code += 1

    def upload_multiple_files(self, FILE_NAME_FULLPATH, bucket_name, file_path):
        for filename in glob.glob(f"{FILE_NAME_FULLPATH}"):
            file_path += filename
            self.upload_file(filename, bucket_name, file_path)

    def download_file(self, bucket_name, filename):
        print(f"-- working on file {filename}")
        try:
            self.client.download_file(
                Bucket=bucket_name, Key=filename, Filename=filename
            )
            print(f"--- {filename} successfully downloaded!")
        except ClientError as be:
            print(f"[CLIENT ERROR]: {be}\n")
            self.return_code += 1
        except Exception as e:
            print(f"[CLIENT ERROR] Unable to download file from COS: {e}")
            self.return_code += 1

    def delete_file(self, bucket_name, filename):
        print(f"-- working on file {filename}")
        try:
            self.client.delete_object(Bucket=bucket_name, Key=filename)
            print(f"--- {filename} successfully deleted!")
        except ClientError as be:
            print(f"[CLIENT ERROR]: {be}\n")
            self.return_code += 1
        except Exception as e:
            print(f"[CLIENT ERROR] Unable to download file from COS: {e}")
            self.return_code += 1

    def main(self):
        # Create S3 Client with constants for IBM COS values
        region = os.environ["COS_REGION"]
        self.client = ibm_boto3.client(
            "s3",
            ibm_api_key_id=os.environ["COS_API_KEY_ID"],
            ibm_service_instance_id=os.environ["COS_INSTANCE_CRN"],
            config=Config(signature_version="oauth"),
            endpoint_url=f"https://s3.{region}.cloud-object-storage.appdomain.cloud",
        )
        ACTION = sys.argv[1]
        FOLDER = ""
        TARGET_PATH = ""
        if ACTION == "UPLOAD":
            FILENAME = sys.argv[2]
            TARGET_PATH = sys.argv[3]
        else:
            FOLDER = sys.argv[2]

        bucket_name = os.environ["COS_BUCKET"]
        self.return_code = 0

        if ACTION == "UPLOAD":
            self.upload_file(bucket_name, TARGET_PATH, FILENAME)
        else:
            objects = self.client.list_objects(Bucket=bucket_name, Prefix=FOLDER)
            for obj in objects["Contents"]:
                if ACTION == "DELETE":
                    self.delete_file(bucket_name, obj["Key"])
                elif ACTION == "DOWNLOAD":
                    self.download_file(bucket_name, obj["Key"])
        return self.return_code


DownloadFromCOS().main()
