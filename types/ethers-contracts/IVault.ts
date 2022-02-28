/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import { FunctionFragment, Result } from "@ethersproject/abi";
import { Listener, Provider } from "@ethersproject/providers";
import { TypedEventFilter, TypedEvent, TypedListener, OnEvent } from "./common";

export interface IVaultInterface extends utils.Interface {
  contractName: "IVault";
  functions: {
    "announceStrategyUpdate(address)": FunctionFragment;
    "balanceOf(address)": FunctionFragment;
    "controller()": FunctionFragment;
    "deposit(uint256)": FunctionFragment;
    "depositFor(uint256,address)": FunctionFragment;
    "doHardWork()": FunctionFragment;
    "getPricePerFullShare()": FunctionFragment;
    "governance()": FunctionFragment;
    "initializeVault(address,address,uint256,uint256)": FunctionFragment;
    "setStrategy(address)": FunctionFragment;
    "setVaultFractionToInvest(uint256,uint256)": FunctionFragment;
    "strategy()": FunctionFragment;
    "underlying()": FunctionFragment;
    "underlyingBalanceInVault()": FunctionFragment;
    "underlyingBalanceWithInvestment()": FunctionFragment;
    "underlyingBalanceWithInvestmentForHolder(address)": FunctionFragment;
    "underlyingUnit()": FunctionFragment;
    "withdraw(uint256)": FunctionFragment;
    "withdrawAll()": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "announceStrategyUpdate",
    values: [string]
  ): string;
  encodeFunctionData(functionFragment: "balanceOf", values: [string]): string;
  encodeFunctionData(
    functionFragment: "controller",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "deposit",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "depositFor",
    values: [BigNumberish, string]
  ): string;
  encodeFunctionData(
    functionFragment: "doHardWork",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getPricePerFullShare",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "governance",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "initializeVault",
    values: [string, string, BigNumberish, BigNumberish]
  ): string;
  encodeFunctionData(functionFragment: "setStrategy", values: [string]): string;
  encodeFunctionData(
    functionFragment: "setVaultFractionToInvest",
    values: [BigNumberish, BigNumberish]
  ): string;
  encodeFunctionData(functionFragment: "strategy", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "underlying",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "underlyingBalanceInVault",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "underlyingBalanceWithInvestment",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "underlyingBalanceWithInvestmentForHolder",
    values: [string]
  ): string;
  encodeFunctionData(
    functionFragment: "underlyingUnit",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "withdraw",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "withdrawAll",
    values?: undefined
  ): string;

  decodeFunctionResult(
    functionFragment: "announceStrategyUpdate",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "balanceOf", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "controller", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "deposit", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "depositFor", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "doHardWork", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getPricePerFullShare",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "governance", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "initializeVault",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setStrategy",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setVaultFractionToInvest",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "strategy", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "underlying", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "underlyingBalanceInVault",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "underlyingBalanceWithInvestment",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "underlyingBalanceWithInvestmentForHolder",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "underlyingUnit",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "withdraw", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "withdrawAll",
    data: BytesLike
  ): Result;

  events: {};
}

export interface IVault extends BaseContract {
  contractName: "IVault";
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IVaultInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    announceStrategyUpdate(
      _strategy: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    balanceOf(_holder: string, overrides?: CallOverrides): Promise<[BigNumber]>;

    controller(overrides?: CallOverrides): Promise<[string]>;

    deposit(
      _amountWei: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    depositFor(
      _amountWei: BigNumberish,
      _holder: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    doHardWork(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    getPricePerFullShare(overrides?: CallOverrides): Promise<[BigNumber]>;

    governance(overrides?: CallOverrides): Promise<[string]>;

    initializeVault(
      _storage: string,
      _underlying: string,
      _toInvestNumerator: BigNumberish,
      _toInvestDenominator: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setStrategy(
      _strategy: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setVaultFractionToInvest(
      _numerator: BigNumberish,
      _denominator: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    strategy(overrides?: CallOverrides): Promise<[string]>;

    underlying(overrides?: CallOverrides): Promise<[string]>;

    underlyingBalanceInVault(overrides?: CallOverrides): Promise<[BigNumber]>;

    underlyingBalanceWithInvestment(
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    underlyingBalanceWithInvestmentForHolder(
      _holder: string,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    underlyingUnit(overrides?: CallOverrides): Promise<[BigNumber]>;

    withdraw(
      _numberOfShares: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    withdrawAll(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;
  };

  announceStrategyUpdate(
    _strategy: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  balanceOf(_holder: string, overrides?: CallOverrides): Promise<BigNumber>;

  controller(overrides?: CallOverrides): Promise<string>;

  deposit(
    _amountWei: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  depositFor(
    _amountWei: BigNumberish,
    _holder: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  doHardWork(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  getPricePerFullShare(overrides?: CallOverrides): Promise<BigNumber>;

  governance(overrides?: CallOverrides): Promise<string>;

  initializeVault(
    _storage: string,
    _underlying: string,
    _toInvestNumerator: BigNumberish,
    _toInvestDenominator: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setStrategy(
    _strategy: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setVaultFractionToInvest(
    _numerator: BigNumberish,
    _denominator: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  strategy(overrides?: CallOverrides): Promise<string>;

  underlying(overrides?: CallOverrides): Promise<string>;

  underlyingBalanceInVault(overrides?: CallOverrides): Promise<BigNumber>;

  underlyingBalanceWithInvestment(
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  underlyingBalanceWithInvestmentForHolder(
    _holder: string,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  underlyingUnit(overrides?: CallOverrides): Promise<BigNumber>;

  withdraw(
    _numberOfShares: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  withdrawAll(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  callStatic: {
    announceStrategyUpdate(
      _strategy: string,
      overrides?: CallOverrides
    ): Promise<void>;

    balanceOf(_holder: string, overrides?: CallOverrides): Promise<BigNumber>;

    controller(overrides?: CallOverrides): Promise<string>;

    deposit(_amountWei: BigNumberish, overrides?: CallOverrides): Promise<void>;

    depositFor(
      _amountWei: BigNumberish,
      _holder: string,
      overrides?: CallOverrides
    ): Promise<void>;

    doHardWork(overrides?: CallOverrides): Promise<void>;

    getPricePerFullShare(overrides?: CallOverrides): Promise<BigNumber>;

    governance(overrides?: CallOverrides): Promise<string>;

    initializeVault(
      _storage: string,
      _underlying: string,
      _toInvestNumerator: BigNumberish,
      _toInvestDenominator: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    setStrategy(_strategy: string, overrides?: CallOverrides): Promise<void>;

    setVaultFractionToInvest(
      _numerator: BigNumberish,
      _denominator: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    strategy(overrides?: CallOverrides): Promise<string>;

    underlying(overrides?: CallOverrides): Promise<string>;

    underlyingBalanceInVault(overrides?: CallOverrides): Promise<BigNumber>;

    underlyingBalanceWithInvestment(
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    underlyingBalanceWithInvestmentForHolder(
      _holder: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    underlyingUnit(overrides?: CallOverrides): Promise<BigNumber>;

    withdraw(
      _numberOfShares: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    withdrawAll(overrides?: CallOverrides): Promise<void>;
  };

  filters: {};

  estimateGas: {
    announceStrategyUpdate(
      _strategy: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    balanceOf(_holder: string, overrides?: CallOverrides): Promise<BigNumber>;

    controller(overrides?: CallOverrides): Promise<BigNumber>;

    deposit(
      _amountWei: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    depositFor(
      _amountWei: BigNumberish,
      _holder: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    doHardWork(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    getPricePerFullShare(overrides?: CallOverrides): Promise<BigNumber>;

    governance(overrides?: CallOverrides): Promise<BigNumber>;

    initializeVault(
      _storage: string,
      _underlying: string,
      _toInvestNumerator: BigNumberish,
      _toInvestDenominator: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setStrategy(
      _strategy: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setVaultFractionToInvest(
      _numerator: BigNumberish,
      _denominator: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    strategy(overrides?: CallOverrides): Promise<BigNumber>;

    underlying(overrides?: CallOverrides): Promise<BigNumber>;

    underlyingBalanceInVault(overrides?: CallOverrides): Promise<BigNumber>;

    underlyingBalanceWithInvestment(
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    underlyingBalanceWithInvestmentForHolder(
      _holder: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    underlyingUnit(overrides?: CallOverrides): Promise<BigNumber>;

    withdraw(
      _numberOfShares: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    withdrawAll(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    announceStrategyUpdate(
      _strategy: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    balanceOf(
      _holder: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    controller(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    deposit(
      _amountWei: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    depositFor(
      _amountWei: BigNumberish,
      _holder: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    doHardWork(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    getPricePerFullShare(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    governance(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    initializeVault(
      _storage: string,
      _underlying: string,
      _toInvestNumerator: BigNumberish,
      _toInvestDenominator: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setStrategy(
      _strategy: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setVaultFractionToInvest(
      _numerator: BigNumberish,
      _denominator: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    strategy(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    underlying(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    underlyingBalanceInVault(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    underlyingBalanceWithInvestment(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    underlyingBalanceWithInvestmentForHolder(
      _holder: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    underlyingUnit(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    withdraw(
      _numberOfShares: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    withdrawAll(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;
  };
}
