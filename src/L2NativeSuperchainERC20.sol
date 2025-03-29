// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SuperchainERC20} from "interop-lib/src/SuperchainERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

contract L2NativeSuperchainERC20 is SuperchainERC20 {
  using Strings for string;

  string private NAME;
  string private SYMBOL;
  uint8 private immutable DECIMALS;
  IERC20 public immutable NATIVE_TOKEN;
  PoolKey public key;
  IPoolManager public poolManager;

  event Deposit(address indexed from, uint256 amount);
  event Withdrawal(address indexed to, uint256 amount);

  constructor(address _nativeToken, address _poolManager) {
    NATIVE_TOKEN = IERC20(_nativeToken);
    NAME = string.concat("SuperWrapped ", NATIVE_TOKEN.name());
    SYMBOL = string.concat("sw", NATIVE_TOKEN.symbol());
    DECIMALS = NATIVE_TOKEN.decimals();
    poolManager = IPoolManager(_poolManager);
  }

  function initialize(PoolKey calldata _key) public {
    key = _key;
  }

  function name() public view virtual override returns (string memory) {
    return NAME;
  }

  function symbol() public view virtual override returns (string memory) {
    return SYMBOL;
  }

  function decimals() public view override returns (uint8) {
    return DECIMALS;
  }

  // Deposit native tokens to receive wrapped tokens
  function deposit(uint256 amount) public payable {
    poolManager.unlock();
    poolManager.swap(key, true, -int256(amount), 0x0);
    _mint(msg.sender, amount);
    NATIVE_TOKEN.transferFrom(msg.sender, address(this), amount);
    emit Deposit(msg.sender, amount);
  }

  // Withdraw native tokens by burning wrapped tokens
  function withdraw(uint256 amount) public {
    require(balanceOf(msg.sender) >= amount, "Insufficient balance");
    _burn(msg.sender, amount);
    NATIVE_TOKEN.transfer(msg.sender, amount);
    emit Withdrawal(msg.sender, amount);
  }
}
