// Uploads the job output to Azure Blob Storage using the job's managed identity.
// No keys or passwords: Container Apps gives the job a token endpoint (IDENTITY_ENDPOINT).
import { readFile } from "node:fs/promises";

const { IDENTITY_ENDPOINT, IDENTITY_HEADER, AZURE_CLIENT_ID, STORAGE_ACCOUNT, STORAGE_CONTAINER } = process.env;
for (const [name, value] of Object.entries({ IDENTITY_ENDPOINT, IDENTITY_HEADER, AZURE_CLIENT_ID, STORAGE_ACCOUNT, STORAGE_CONTAINER })) {
  if (!value) throw new Error(`Missing environment variable ${name}`);
}

async function storageToken() {
  const url = new URL(IDENTITY_ENDPOINT);
  url.searchParams.set("resource", "https://storage.azure.com/");
  url.searchParams.set("api-version", "2019-08-01");
  url.searchParams.set("client_id", AZURE_CLIENT_ID);
  const response = await fetch(url, { headers: { "X-IDENTITY-HEADER": IDENTITY_HEADER } });
  if (!response.ok) throw new Error(`Token request failed: ${response.status} ${await response.text()}`);
  return (await response.json()).access_token;
}

async function upload(token, localPath, blobPath) {
  const body = await readFile(localPath);
  const url = `https://${STORAGE_ACCOUNT}.blob.core.windows.net/${STORAGE_CONTAINER}/${blobPath}`;
  const response = await fetch(url, {
    method: "PUT",
    body,
    headers: {
      Authorization: `Bearer ${token}`,
      "x-ms-version": "2021-08-06",
      "x-ms-blob-type": "BlockBlob",
      "Content-Type": "application/json",
    },
  });
  if (!response.ok) throw new Error(`Upload of ${blobPath} failed: ${response.status} ${await response.text()}`);
  console.log(`Uploaded ${blobPath} (${body.length} bytes)`);
}

const token = await storageToken();
const dir = "output";
await upload(token, `${dir}/latest.json`, "runs/latest.json");
await upload(token, `${dir}/status.json`, "runs/status.json");
