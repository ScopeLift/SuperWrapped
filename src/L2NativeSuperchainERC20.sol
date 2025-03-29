// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SuperchainERC20} from "interop-lib/src/SuperchainERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";

contract L2NativeSuperchainERC20 is SuperchainERC20 {
  using Strings for string;

  string private _name;
  string private _symbol;
  uint8 private immutable _decimals;
  IERC20 public immutable nativeToken;

  event Deposit(address indexed from, uint256 amount);
  event Withdrawal(address indexed to, uint256 amount);

  constructor(address nativeToken_) {
    nativeToken = IERC20(nativeToken_);
    _name = string.concat("SuperWrapped ", nativeToken.name());
    _symbol = string.concat("sw", nativeToken.symbol());
    _decimals = nativeToken.decimals();
  }

  function name() public view virtual override returns (string memory) {
    return _name;
  }

  function symbol() public view virtual override returns (string memory) {
    return _symbol;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  // Deposit native tokens to receive wrapped tokens
  function deposit(uint256 amount) public payable {
    _mint(msg.sender, amount);
    nativeToken.transferFrom(msg.sender, address(this), amount);
    emit Deposit(msg.sender, amount);
  }

  // Withdraw native tokens by burning wrapped tokens
  function withdraw(uint256 amount) public {
    require(balanceOf(msg.sender) >= amount, "Insufficient balance");
    _burn(msg.sender, amount);
    nativeToken.transfer(msg.sender, amount);
    emit Withdrawal(msg.sender, amount);
  }
}
