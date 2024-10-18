
# Sophon Light Node

## How to run your Sophon's Light Node
If you have purchased a license to run a node at Sophon, you can start doing so with a simple click.

Use our Railway template to spin up an Sophon Light Node:

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/wEhaxi?referralCode=qB-i6S)

## Reliability
It is important you set up some monitoring to ensure your node is always up and running. Even though we will have some tolerance to failures and downtimes, our rewards programme will calculate rewards based on uptime. 

## Environment variables
If you're using Railway, all variables are pre-populated for you except for your **delegated wallet address**. 

While this is not required to run a node, bear in mind that if you want to participate in Sophon's reward programme, you MUST set this with a valid delegated wallet. *If you either do not pass any wallet or you pass a wallet that is NOT delegated, the node will run but you won't be eligible for rewards.*

If decide not to use Railway, you can use our Docker image making sure to set the following environment variables:
```
MONITOR_URL=stg-sophon-node-monitor.up.railway.app # TODO: add mainnet URL
DELEGATED_WALLET= # your delegated wallet address
PUBLIC_DOMAIN= # this is the public domain URL where the node is running
```

If you want to run the node directly, you must call it this way:
```bash
./sophonup.sh --wallet YOUR_DELEGATED_WALLET --public-domain YOUR_PUBLIC_DOMAIN --monitor-url SOPHON_MONITOR_URL
```
*If running it directly, make sure you register your node on Sophon's monitor (more details on [Development Docs](DEV_README.md))*

## FAQ

### How do I earn rewards?
To be able to earn rewards you need to make sure that the light node is registered on Sophon so we can monitor your node's activity.

By using the Railway template (or the Docker image), we automatically register your node for you.

### I don't want to use Railway
If you do not wish to use this Railway template to spin up you light node, you can take a look at the [Development Docs](DEV_README.md)

### I want to change my node URL (or IP)
You can change your public domain by making a `PUT /nodes` request sending the relevant information in the body of the message:

```
curl -X PUT "/nodes" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer SIGNED_MESSAGE" \
-d '{ "id": "NODE_ID", "delegateAddress": "DELEGATE_ADDRESS", "url": "NEW_URL", "timestamp": TIMESTAMP}'
```

*This call requires you to sign a message so we can verify you are the owner of the delegated address.*

### How do I sign the message?
The signed message is a UNIX timestamp (in milliseconds format) signed with your delegated wallet. Signatures expire after 15 minutes.

You can use [Etherscan](https://etherscan.io/verifiedSignatures#) to sign messages.