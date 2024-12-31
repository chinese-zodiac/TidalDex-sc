# TidalDex

0 fee p2p dex with no governance

## Deployments

### BSC Testnet

| Contract                          | Address                                    |
| --------------------------------- | ------------------------------------------ |
| Factory                           | 0x89A85a443a3c4707d0d186A4766b641681219D79 |

### BSC Mainnet

| Contract                          | Address                                    |
| --------------------------------- | ------------------------------------------ |
| Factory                           | 0x89A85a443a3c4707d0d186A4766b641681219D79 |

## build
forge build --via-ir

## deployment

Key variables are set in the script, and should be updated correctly for the network.

forge script script/v2/DeployTenXLaunch.s.sol:DeployTenXLaunch --broadcast --verify -vvv --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY -i 1 --sender $DEPLOYER_ADDRESS
