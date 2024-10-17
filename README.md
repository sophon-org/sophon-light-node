
# Sophon Light Node

## How to run your Sophon's Light Node
If you have purchased a license to run a node at Sophon, you can start doing so with a simple click.

Use our Railway template to spin up an Sophon Light Node:

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/wEhaxi?referralCode=qB-i6S)

## Environment variables
If you're using Railway, all variables are pre-populated for you except for your **delegated wallet address**. 

While this is not required, bear in mind that if you want to participate in Sophon's reward programme, you MUST set this with a valid delegated wallet. *If you either do not pass any wallet or you pass a wallet that is NOT delegated, the node will run but you won't be eligible for rewards.*

If you're using Docker and you want your node to be registered (to participat in the rewards programme) you must set the following environment variables
```
MONITOR_URL=stg-sophon-node-monitor.up.railway.app # TODO: add mainnet URL
DELEGATED_WALLET= # your delegated wallet address
PUBLIC_DOMAIN= # this is public domain URL where the node is running
```

If you want to run the node directly, you must call it this way:
```bash
./availup.sh --wallet YOUR_DELEGATED_WALLET --public-domain YOUR_PUBLIC_DOMAIN --monitor-url SOPHON_MONITOR_URL
```

## FAQ

### How do I earn rewards?
To be able to earn rewards you need to make sure that the light node is registered on Sophon so we can monitor your node's activity.

By using the Railway template, we automatically register your node for you.

### I don't want to use Railway
If you do not wish to use this Railway template to spin up you light node, you can take a look at the [Development Docs](DEV_README.md)

### I want to change my node URL (or IP)
TODO (@ryan)
You can change your public domain by making a POST /nodes request sending the relevant information in the body of the message:

```
curl -X POST /nodes \
-H "Content-Type: application/json" \
-d '{
  "delegated_address": YOUR_DELEGATED_ADDRESS,
  "url": YOUR_NEW_URL
  "signed_message": YOU_SIGNED_MESSAGE
}'
```

*This call requires you to sign a message so we can verify you are the owner of the delegated address*

### How do I sign the message?
TODO (@ryan)