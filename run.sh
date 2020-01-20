#!/bin/bash
if [[ -z ${SECRET_ID} ]]
then
    echo "please provide aunsight secret id where AWS creds are located. exiting"
    sleep 1
    exit 1
fi

if [[ -z ${CERT_SECRET_ID} ]]
then
    echo "missing cert Secret ID location."
    sleep 1
    exit 1
fi

if [[ -z ${DOMAIN_NAME} ]]
then
    echo "missing domain to renew exiting."
    sleep 1
    exit 1
fi

mkdir -p /home/user/

echo "downloading AWS creds from Aunsight Secrets"

au2 c se ${AU_ORGANIZATION}

SECRET=$(au2 secret download ${SECRET_ID})



echo "Genrating Cert for ${DOMAIN_NAME}"
echo "Setting AWS creds from host"
export AWS_ACCESS_KEY_ID=$(echo $SECRET | jq -r .AWS_ACCESS_KEY_ID)
export AWS_SECRET_ACCESS_KEY=$(echo $SECRET | jq -r .AWS_SECRET_ACCESS_KEY )


certbot certonly -n --agree-tos --email devops@aunsight.com --dns-route53  --expand --server https://acme-v02.api.letsencrypt.org/directory -d ${DOMAIN_NAME}
CLEANED_DOMAIN_NAME=${DOMAIN_NAME#*.}
echo "validation Cert genration Completed."

ls -ls /etc/letsencrypt/live/${CLEANED_DOMAIN_NAME}/fullchain.pem || (echo "Cert Gen error.. Full chain Cert dont exist.. exiting"  && exit 1 )
ls -ls /etc/letsencrypt/live/${CLEANED_DOMAIN_NAME}/privkey.pem || (echo "Cert Gen error.. Cert Private Key dont exist.. exiting"  && exit 1 )
TEMP_PATH=/tmp/temp.pem

cat /etc/letsencrypt/live/${CLEANED_DOMAIN_NAME}/privkey.pem /etc/letsencrypt/live/${CLEANED_DOMAIN_NAME}/fullchain.pem > ${TEMP_PATH}
echo "Uploading certs to Aunsight."
au2 secret ingest -i ${CERT_SECRET_ID} --file ${TEMP_PATH} --force-overwrite

# #JIRA STUFF...
# #TODO
JIRA_USERNAME=$(echo $SECRET | jq -r .JIRA_USER )
JIRA_PASSWORD=$(echo $SECRET | jq -r .JIRA_TOKEN )

NAME_OF_TICKET="Renew Cert for ${DOMAIN_NAME}"
#Search for Ticket in last 7 days.
LIST_OF_ISSUES=$(curl -X POST \
    https://aunalytics.atlassian.net/rest/api/2/search \
    -u ${JIRA_USERNAME}:${JIRA_PASSWORD} \
    -H 'Content-Type: application/json' \
    -d '{
	"jql" : "project = AUN AND summary ~\"'"${CLEANED_DOMAIN_NAME}"'\" AND createdDate >= startOfDay(\"-7\") ORDER BY status ASC, created DESC",
	"maxResults" : 5,
	"fields": ["id","key","summary"]
}')

echo "LIST OF ISSUES : ${LIST_OF_ISSUES}"
if [[ $(echo ${LIST_OF_ISSUES} | jq -r .total ) -gt 0 ]]
then
    echo "ISSUE EXIST"
    echo "Key of isssue : $(echo ${LIST_OF_ISSUES} | jq -r .issues[].key) "
    if  [[ "$(echo ${LIST_OF_ISSUES} | jq -r .issues[].fields.summary)" == $NAME_OF_TICKET ]]
    then
        echo "SUCCEDED"
        sleep 1
        exit 1
    fi
else
    echo $NAME_OF_TICKET
    echo $DOMAIN_NAME
    echo "Creating Issue."
    JIRA_RES=$(curl  -X POST \
        https://aunalytics.atlassian.net/rest/api/2/issue/ \
        -u ${JIRA_USERNAME}:${JIRA_PASSWORD} \
        -H "Content-Type: application/json" \
        -d '{
        "fields": {
       "project":{"key": "AUN"},
       "summary": "'"${NAME_OF_TICKET}"'",
       "description": "Creating Ticket for renewing cert for '"${DOMAIN_NAME}"'",
       "issuetype": {"name": "Task"},
       "assignee": {"name" : "ppatel"}
       }
    }')
    TICKET_ID=$(echo ${JIRA_RES} | jq -r .key)
fi

#Uploading Certs to Repo
cd /home/user
mkdir -p /home/user/.ssh
GIT_SSH_KEY_PATH="/home/user/.ssh/id_rsa"

echo "setting ansible password."
ANSIBLE_VAULT_PASS_FILE="/home/user/.ansiblepass"
export ANSIBLE_VAULT_PASS=$(echo $SECRET | jq -r .ANSIBLE_VAULT_PASS)
echo ${ANSIBLE_VAULT_PASS} > ${ANSIBLE_VAULT_PASS_FILE}

echo -e $(echo $SECRET | jq -r .GIT_SSH_KEY)  > ${GIT_SSH_KEY_PATH}
chmod -R 600 ${GIT_SSH_KEY_PATH}
chmod -R 600 /home/user/.ssh
export GIT_SSH_COMMAND="ssh -i ${GIT_SSH_KEY_PATH} -o StrictHostKeyChecking=no "

git config --global user.name "Auto Cert"
git config --global user.email ppatel@aunalytics.com
git clone git@bitbucket.org:au-developers/aunsight-deployment-ansible.git
cd aunsight-deployment-ansible/ansible || (echo "git Failed exiting " && exit 1 )
LIST_OF_KEY_PATH=$(find . -name "\*.${CLEANED_DOMAIN_NAME}.privkey.pem")
LIST_OF_FULLCHAIN_PATH=$(find . -name "\*.${CLEANED_DOMAIN_NAME}.fullchain.pem")
if [[ -z ${LIST_OF_FULLCHAIN_PATH} && -z ${LIST_OF_KEY_PATH} ]]
then
    echo "Cert Files not found"
    sleep 1
    exit 1
fi

for i in "${LIST_OF_KEY_PATH}"
do
    echo "replacing key files at ${i}"
    cp /etc/letsencrypt/live/${CLEANED_DOMAIN_NAME}/privkey.pem $i
    ansible-vault encrypt $i --vault-password-file=${ANSIBLE_VAULT_PASS_FILE}
done

for i in "${LIST_OF_FULLCHAIN_PATH}"
do
    echo "replacing Full chain files at ${i}"
    cp /etc/letsencrypt/live/${CLEANED_DOMAIN_NAME}/fullchain.pem $i
    ansible-vault encrypt $i --vault-password-file=${ANSIBLE_VAULT_PASS_FILE}
done
git pull
git checkout -b "${TICKET_ID}-cert-update"
# git branch -b "${TICKET_ID}-cert-update"
git add .
git commit -m "${TICKET_ID} updated Certs."
git push -u origin "${TICKET_ID}-cert-update"
sleep 5
