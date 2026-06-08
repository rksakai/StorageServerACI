import os
import mimetypes
from pathlib import PurePosixPath
from azure.storage.blob import (
    BlobServiceClient,
    ContentSettings,
)

class AzureUploader:
    """Gerencia uploads para Azure Blob Storage."""

    def __init__(self):
        account_name = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
        account_key = os.environ["AZURE_STORAGE_ACCOUNT_KEY"]
        self.container_name = os.environ["AZURE_STORAGE_CONTAINER_NAME"]

        conn_str = (
            f"DefaultEndpointsProtocol=https;"
            f"AccountName={account_name};"
            f"AccountKey={account_key};"
            f"EndpointSuffix=core.windows.net"
        )
        self.client = BlobServiceClient.from_connection_string(conn_str)
        self.container_client = self.client.get_container_client(
            self.container_name
        )

    def upload_file(self, file_stream, blob_path: str) -> dict:
        """
        Faz upload de um único arquivo.
        blob_path: caminho relativo dentro do container (preserva subdiretórios)
        """
        # Normaliza separadores para '/'
        blob_path = blob_path.replace("\\", "/").lstrip("/")

        content_type, _ = mimetypes.guess_type(blob_path)
        content_settings = ContentSettings(
            content_type=content_type or "application/octet-stream"
        )

        blob_client = self.container_client.get_blob_client(blob_path)
        file_stream.seek(0)
        blob_client.upload_blob(
            file_stream,
            overwrite=True,
            content_settings=content_settings,
        )

        return {
            "blob_path": blob_path,
            "url": blob_client.url,
        }

    def list_blobs(self, prefix: str = "") -> list:
        """Lista blobs no container com prefixo opcional."""
        blobs = []
        for blob in self.container_client.list_blobs(name_starts_with=prefix):
            blobs.append(
                {
                    "name": blob.name,
                    "size": blob.size,
                    "last_modified": blob.last_modified.isoformat()
                    if blob.last_modified
                    else None,
                    "content_type": blob.content_settings.content_type
                    if blob.content_settings
                    else None,
                }
            )
        return blobs

    def delete_blob(self, blob_path: str) -> bool:
        """Remove um blob do container."""
        blob_path = blob_path.replace("\\", "/").lstrip("/")
        blob_client = self.container_client.get_blob_client(blob_path)
        blob_client.delete_blob()
        return True