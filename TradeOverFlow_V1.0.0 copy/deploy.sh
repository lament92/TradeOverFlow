#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- NEW ---
# Check if the credentials file exists
if [ ! -f "credentials" ]; then
    echo "Error: 'credentials' file not found."
    echo "Please create it with your AWS Learner Lab credentials."
    exit 1
fi

# Tell AWS tools (like Terraform) to use the local credentials file.
export AWS_SHARED_CREDENTIALS_FILE=./credentials
echo "--- Using local 'credentials' file for AWS authentication ---"
echo ""
# --- END NEW ---

echo "--- Zipping Lambda Functions ---"
rm -rf zips && mkdir zips

for function_dir in src/*/; do
    dir_name=$(basename "$function_dir")
    echo "Zipping $dir_name..."
    (cd "$function_dir" && zip -r "../../zips/${dir_name}.zip" .)
done
echo "All functions zipped."
echo ""

echo "--- Initializing Terraform ---"
terraform init -input=false
echo ""

echo "--- Applying Terraform Configuration ---"
terraform apply -auto-approve -input=false
echo ""

echo "--- Writing API URL to api.txt ---"
terraform output -raw invoke_url > api.txt
echo "Deployment successful. URL saved to api.txt"
cat api.txt