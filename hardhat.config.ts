import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-gas-reporter';

import chai from 'chai';
import { solidity } from 'ethereum-waffle';
import { HardhatUserConfig } from 'hardhat/config';

const keys = require('./dev-keys.json');

chai.use(solidity);

export const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      forking: {
        url: `https://arbitrum-mainnet.infura.io/v3/${keys.infuraKey}`,
        blockNumber: 7642700,
      },
    },
    arbitrum: {
      url: `https://arbitrum-mainnet.infura.io/v3/${keys.infuraKey}`
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
  etherscan: {
    apiKey: keys.etherscanApiKey,
  },
};

// noinspection JSUnusedGlobalSymbols
export default config;
