export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="us-east-1"

sed -i 's/<ACCOUNT_ID>/${ACCOUNT_ID}/g' 04-backend-deployment.yml
sed -i 's/<ACCOUNT_ID>/${ACCOUNT_ID}/g' 05-frontend-deployment.yml

sed -i 's/backned/backend/g' 04-backend-deployment.yml
sed -i 's/frontned/frontend/g' 05-frontend-deployment.yml


