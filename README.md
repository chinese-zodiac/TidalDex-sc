# TidalDex

0 fee p2p dex with no governance

## Deployments

### BSC Testnet

| Contract                          | Address                                    |
| --------------------------------- | ------------------------------------------ |
| Factory                           | 0x907e8C7D471877b4742dA8aA53d257d0d565A47E |
| Router                            | 0x71aB950a0C349103967e711b931c460E9580c631 |

### BSC Mainnet

| Contract                          | Address                                    |
| --------------------------------- | ------------------------------------------ |
| Factory                           | 0x907e8C7D471877b4742dA8aA53d257d0d565A47E |
| Router                            | 0x71aB950a0C349103967e711b931c460E9580c631 |

## build
forge build --via-ir

## deployment

Key variables are set in the script, and should be updated correctly for the network.

forge script script/v2/DeployTenXLaunch.s.sol:DeployTenXLaunch --broadcast --verify -vvv --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY -i 1 --sender $DEPLOYER_ADDRESS
