import { BaseContract } from 'ethers';
import { CrvPool } from '../../src/types/CrvPool';
import { CrvRewardNotifier } from '../../src/types/CrvRewardNotifier';
import { CrvPool__factory } from '../../src/types/factories/CrvPool__factory';
import { CrvRewardNotifier__factory } from '../../src/types/factories/CrvRewardNotifier__factory';
import { IERC20__factory } from '../../src/types/factories/IERC20__factory';
import { IGauge__factory } from '../../src/types/factories/IGauge__factory';
import { IUniswapV2Router02__factory } from '../../src/types/factories/IUniswapV2Router02__factory';
import { IUniswapV3Router__factory } from '../../src/types/factories/IUniswapV3Router__factory';
import { IWETH__factory } from '../../src/types/factories/IWETH__factory';
import { IERC20 } from '../../src/types/IERC20';
import { IGauge } from '../../src/types/IGauge';
import { IUniswapV2Router02 } from '../../src/types/IUniswapV2Router02';
import { IUniswapV3Router } from '../../src/types/IUniswapV3Router';
import { IWETH } from '../../src/types/IWETH';

// ************************* External Contract Addresses *************************

export const CRV = new BaseContract(
  '0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978',
  IERC20__factory.createInterface(),
) as IERC20

export const CRV_TRI_CRYPTO = new BaseContract(
  '0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2',
  IERC20__factory.createInterface(),
) as IERC20

export const CRV_TRI_CRYPTO_GAUGE = new BaseContract(
  '0x97E2768e8E73511cA874545DC5Ff8067eB19B787',
  IGauge__factory.createInterface(),
) as IGauge

export const CRV_TRI_CRYPTO_POOL = new BaseContract(
  '0x960ea3e3C7FB317332d990873d354E18d7645590',
  CrvPool__factory.createInterface(),
) as CrvPool

export const DAI = new BaseContract(
  '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1',
  IERC20__factory.createInterface(),
) as IERC20

export const LINK = new BaseContract(
  '0xf97f4df75117a78c1A5a0DBb814Af92458539FB4',
  IERC20__factory.createInterface(),
) as IERC20

export const SUSHI = new BaseContract(
  '0xd4d42F0b6DEF4CE0383636770eF773390d85c61A',
  IERC20__factory.createInterface(),
) as IERC20

export const SUSHI_ROUTER = new BaseContract(
  '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506',
  IUniswapV2Router02__factory.createInterface(),
) as IUniswapV2Router02

export const UNI = new BaseContract(
  '0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0',
  IERC20__factory.createInterface(),
) as IERC20

export const UNISWAP_V3_ROUTER = new BaseContract(
  '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  IUniswapV3Router__factory.createInterface(),
) as IUniswapV3Router

export const USDC = new BaseContract(
  '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8',
  IERC20__factory.createInterface(),
) as IERC20

export const USDT = new BaseContract(
  '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
  IERC20__factory.createInterface(),
) as IERC20

export const WBTC = new BaseContract(
  '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f',
  IERC20__factory.createInterface(),
) as IERC20

export const WETH = new BaseContract(
  '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
  IWETH__factory.createInterface(),
) as IWETH

export const CRV_REWARD_NOTIFIER = new BaseContract(
  '0x9044E12fB1732f88ed0c93cfa5E9bB9bD2990cE5',
  CrvRewardNotifier__factory.createInterface(),
) as CrvRewardNotifier

// ************************* General Constants *************************

export const SecondsInYear = 31_536_000;

// ************************* Network Addresses Addresses *************************

export const CrvDistributorAddress = '0x7EeAC6CDdbd1D0B8aF061742D41877D7F707289a';
export const CrvWhaleAddress = '0x4A65e76bE1b4e8dd6eF618277Fa55200e3F8F20a';

// ************************* Harvest Contract Addresses *************************

export const ControllerAddress = '';
export const RewardForwarderAddress = '';
export const StorageAddress = '';
export const UniversalLiquidatorAddress = '';
export const VaultImplementationV2 = '';

// ************************* Harvest Params *************************

export const DefaultImplementationDelay = 60 * 60 * 12; // 12 hours
