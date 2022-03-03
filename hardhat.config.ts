import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-truffle5';

import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import { HardhatUserConfig } from 'hardhat/config';

const keys = require('./dev-keys.json');

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      forking: {
        url: 'https://mainnet.infura.io/v3/' + keys.infuraKey,
        // url: "https://eth-mainnet.alchemyapi.io/v2/" + keys.alchemyKey,
        blockNumber: 11807770, // <-- edit here
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.5.16',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 2000000,
  },
  typechain: {
    outDir: 'src/types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ['externalArtifacts/*.json'], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
  },
};

// noinspection JSUnusedGlobalSymbols
export default config;