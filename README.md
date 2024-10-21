
# Sophon Light Node

## How to run your Sophon's Light Node
If you have purchased a license to run a node at Sophon, you must run a light node to earn rewards

### Using Railway

Use our Railway template to spin up an Sophon Light Node in one click

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/wEhaxi?referralCode=qB-i6S)

## Using Docker
Alternatively, you can use our Docker image

[![Docker](https://cdn.icon-icons.com/icons2/2530/PNG/128/dockerhub_button_icon_151899.png)](https://hub.docker.com/r/sophonhub/sophon-light-node)

```
# pull docker image
docker pull --platform linux/amd64 sophonhub/sophon-light-node

# run node
docker run -d --name sophon-light-node sophonhub/sophon-light-node

# if you want to be eligible for rewards you must pass the required env vars
docker run -d --name sophon-light-node \
    -e DELEGATED_WALLET=YOUR_DELEGATED_WALLET \
    -e PUBLIC_DOMAIN=YOUR_NODE_PUBLIC_URL \
    sophonhub/sophon-light-node
```

## Reliability
It is important you set up some monitoring to ensure your node is always up and running. Even though we will have some tolerance to failures and downtimes, our rewards programme will calculate rewards based on uptime. 

## Environment variables
If you're using Railway, all variables are pre-populated for you except for your **delegated wallet address**. 

While this is not required to run a node, bear in mind that if you want to participate in Sophon's reward programme, you MUST set your delegated wallet address. *If you either do not pass any wallet or you pass a wallet that is NOT delegated, the node will run but you won't be eligible for rewards.*

If decide not to use Railway, you can use our Docker image making sure to set the following environment variables:
```
DELEGATED_WALLET= # your delegated wallet address
PUBLIC_DOMAIN= # this is the public domain URL where the node is running
```

## FAQ

### How do I earn rewards?
To be able to earn rewards you need to make sure that the light node is registered on Sophon so we can monitor your node's activity.

By using the Railway template (or the Docker image), we automatically register your node for you.

### I want to change my node URL (or IP)
You can change your public domain by making a `PUT /nodes` request sending the relevant information in the body of the message:

```
curl -X PUT "/nodes" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer SIGNED_MESSAGE" \
-d '{ "id": "NODE_ID", "delegateAddress": "DELEGATE_ADDRESS", "url": "NEW_URL", "timestamp": TIMESTAMP}'
```

### I want to delete my node
```
curl -X DELETE "/nodes" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer SIGNED_MESSAGE" \
-d '{ "id": "NODE_ID", "delegateAddress": "DELEGATE_ADDRESS", "timestamp": TIMESTAMP}'
```
### I want to retrieve all my nodes
curl -X GET "/nodes?delegateAddress=DELEGATE_ADDRESS&timestamp=TIMESTAMP" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer SIGNED_MESSAGE"

*This call requires you to sign a message so we can verify you are the owner of the delegated address.*

### How do I sign the message?
The signed message is a UNIX timestamp (in milliseconds format) signed with your delegated wallet. Signatures expire after 15 minutes.

You can use [Etherscan](https://etherscan.io/verifiedSignatures#) to sign messages.