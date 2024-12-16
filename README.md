
# Sophon Light Node

The Sophon Light Node are lightweight software designed to perform simpler tasks within the Sophon network. It is a cost-effective way to participate in the network, increasing the opportunity for Sophon Guardians to be rewarded, and for the community to participate.

Know more in our [Docs](https://docs.sophon.xyz/sophon/sophon-guardians-and-nodes/sophon-nodes).

## How to run your Sophon's Light Node

For a guided experience, you can visit the [Guardians Dashboard](https://guardian.sophon.xyz).

### Using third party node as a service providers

Here is a list of providers that allow you to run a Sophon Light Node directly in their interface:
- [Easeflow](https://easeflow.io)

### Using Railway

Use our Railway template to spin up an Sophon Light Node in one click

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/wEhaxi?referralCode=qB-i6S)

Bare in mind that you must have a Railway account and that costs might apply.

### Using Docker

Use our Docker image to run the Light Node anywhere you want. The main requirement is that you must be able to expose the container to the internet through a fixed domain/URL/IP.

[![Docker](https://cdn.icon-icons.com/icons2/2530/PNG/128/dockerhub_button_icon_151899.png)](https://hub.docker.com/r/sophonhub/sophon-light-node)

More info on the following env variables on [Environment variables](#environment-variables)

```
# pull docker image
docker pull --platform linux/amd64 sophonhub/sophon-light-node

# if you want to use the testnet environment
docker pull --platform linux/amd64 sophonhub/sophon-light-node:latest-stg

# run node
docker run -d --name sophon-light-node sophonhub/sophon-light-node

# if you want to be eligible for rewards you must pass the required env vars
docker run -d --name sophon-light-node \
    -e OPERATOR_ADDRESS=<You operator wallet address> \
    -e DESTINATION_ADDRESS=<The rewards destination wallet address> \
    -e PERCENTAGE=<The percentage this node will charge as rewards fee from delegators> \
    -e PUBLIC_DOMAIN=<Your public URL/IP, including Protocol an acessible PORT if not 8080> \
    -e PORT=<PORT you want the service to run. It defaults to 7007> \
    -p <External acessible PORT>:<Internal port defined above, or defaults to 7007> \
    sophonhub/sophon-light-node

# Don't forget to change to sophonhub/sophon-light-node:latest-stg for testnet in case you have both images
```

## Reliability
If you are running the node on any VPS (including Railway) or even locally on your machine, it is important you set up some monitoring to ensure your node is always up and running. Even though we will have some tolerance to failures and downtimes, our rewards programme will calculate rewards based on uptime.

## Environment variables

While this is not required to run a node, bear in mind that if you want to participate in Sophon's Guardians Reward Program, you MUST set your operator wallet address. *If you either do not pass any address or you pass an address that doesn't contain any Guardian Membership delegations, the node will run but you won't be eligible for rewards. Now more about rewards in our [Docs](https://docs.sophon.xyz/sophon/sophon-guardians-and-nodes/node-rewards).*

If you're using Railway, all variables are pre-populated for you except for your **operator wallet address** and **percentage**. 
If decide not to use Railway, you can use our Docker image making sure to set the following environment variables:
```
OPERATOR_ADDRESS= # [OPTIONAL] Your Light Node operator address, which is the one that must receive delegations to be eligible to receive rewards. The more delegations, the more rewards, with a cap limit of 20 delegations. **Required** if you want to participate on the rewards programme.

DESTINATION_ADDRESS= # [OPTIONAL] this is the wallet address that will receive rewards from the Guardians programme (based on the percetage defined above). Most of the times it will be the operator address, but you can define a different one. Defaults to OPERATOR_ADDRESS if not set.

PERCENTAGE= # [OPTIONAL] The percentage this node will charge as rewards fee from delegators. Basically, rewards are calculated based on delegated amount, and this percentage defines how much goes to you as node operator, and the rest goes to delegators. It must be a decimal from 0.00 to 100. Only 2 decimals allowed. **Required** if OPERATOR_ADDRESS is set, ignored otherwise.

PUBLIC_DOMAIN= # [OPTIONAL] this is the public domain URL/IP where the node is running so it can be reach by the monitoring servers. Please include protocol or it defaults to HTTPS. **Required** if OPERATOR_ADDRESS is set.

PORT= # [OPTIONAL] In case you want the service to run on a different PORT than 7007
```

## FAQ

### How do I earn rewards?
To be able to earn rewards you need to make sure that the Light Node is registered on Sophon so we can monitor your node's activity.

By using the Railway template (or the Docker image), we automatically register your node for you given the right environment variables are passed.

### I want to retrieve all nodes information
```
curl -X GET "https://monitor.sophon.xyz/nodes"
```

### I want to retrieve my node information
You can filter nodes by using the `operators` filter. It takes comma-separated addresses.
```
curl -X GET "https://monitor.sophon.xyz/nodes?operators=0xOPERATOR1,0xOPERATOR2"
```
Additionally, you can also define the `page` and `per_page` params. For example:
```
curl -X GET "https://monitor.sophon.xyz/nodes?page=3&per_page=10"
```
will return 10 nodes per page and we are asking for the 3rd page.

### I want to change some params of my node
You can change your node's URL (or IP) and/or destination address: 
```
curl -X PUT "https://monitor.sophon.xyz/nodes" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer SIGNED_MESSAGE" \
-d '{ "operator": "OPERATOR_ADDRESS", "url": "NEW_URL", "destination": "NEW_DESTINATION", "timestamp": TIMESTAMP}'
```
*This calls requires you to sign a message so we can verify you are the owner of the operator address.*

### I want to delete my node
Registered nodes can not be deleted.

### How do I sign the authorization message?
The signed message is a UNIX timestamp (in seconds format) signed with your operator wallet. Signatures expire after 15 minutes.

You can use [Etherscan](https://etherscan.io/verifiedSignatures#) to sign messages.
