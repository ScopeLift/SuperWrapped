// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {L2NativeSuperchainERC20} from "../src/L2NativeSuperchainERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract L2NativeSuperchainERC20Test is Test {
  L2NativeSuperchainERC20 public wrappedToken;
  MockERC20 public nativeToken;
  address public user = address(0x1);
  uint256 public constant INITIAL_BALANCE = 100_000e18;

  event Deposit(address indexed from, uint256 amount);
  event Withdrawal(address indexed to, uint256 amount);

  function setUp() public {
    // Deploy mock native token
    nativeToken = new MockERC20("Native Token", "NT", 18);
    nativeToken.mint(user, INITIAL_BALANCE);

    // Deploy wrapped token
    wrappedToken = new L2NativeSuperchainERC20(address(nativeToken));
  }
}

contract Constructor is L2NativeSuperchainERC20Test {
  function test_Constructor() public {
    assertEq(wrappedToken.name(), string.concat("SuperWrapped ", nativeToken.name()));
    assertEq(wrappedToken.symbol(), string.concat("sw", nativeToken.symbol()));
    assertEq(wrappedToken.decimals(), nativeToken.decimals());
  }
}

contract Deposit is L2NativeSuperchainERC20Test {
  function testFuzz_Deposit(uint256 depositAmount) public {
    // Bound the deposit amount to be between 1 and the user's balance
    depositAmount = bound(depositAmount, 1, INITIAL_BALANCE);

    vm.startPrank(user);
    nativeToken.approve(address(wrappedToken), depositAmount);

    vm.expectEmit();
    emit Deposit(user, depositAmount);

    wrappedToken.deposit(depositAmount);
    vm.stopPrank();

    // Check balances after deposit
    assertEq(wrappedToken.balanceOf(user), depositAmount, "Incorrect wrapped token balance");
    assertEq(
      nativeToken.balanceOf(user),
      INITIAL_BALANCE - depositAmount,
      "Incorrect native token balance for user"
    );
    assertEq(
      nativeToken.balanceOf(address(wrappedToken)),
      depositAmount,
      "Incorrect native token balance for contract"
    );
  }

  function testFuzz_DepositFailsWithoutApproval(uint256 depositAmount) public {
    // Bound the deposit amount to be between 1 and max uint256
    depositAmount = bound(depositAmount, 1, type(uint256).max);

    vm.startPrank(user);
    vm.expectRevert();
    wrappedToken.deposit(depositAmount);
    vm.stopPrank();
  }

  function testFuzz_DepositFailsWithInsufficientBalance(uint256 depositAmount) public {
    // Bound the deposit amount to be greater than the user's balance
    depositAmount = bound(depositAmount, INITIAL_BALANCE + 1, type(uint256).max);

    vm.startPrank(user);
    nativeToken.approve(address(wrappedToken), depositAmount);
    vm.expectRevert();
    wrappedToken.deposit(depositAmount);
    vm.stopPrank();
  }
}

contract Withdraw is L2NativeSuperchainERC20Test {
  function testFuzz_Withdraw(uint256 depositAmount, uint256 withdrawAmount) public {
    // Bound the deposit amount to be between 1 and the user's balance
    depositAmount = bound(depositAmount, 1, INITIAL_BALANCE);
    // Bound the withdraw amount to be between 1 and the deposit amount
    withdrawAmount = bound(withdrawAmount, 1, depositAmount);

    // First deposit
    vm.startPrank(user);
    nativeToken.approve(address(wrappedToken), depositAmount);
    wrappedToken.deposit(depositAmount);

    // Then withdraw
    vm.expectEmit(true, false, false, true);
    emit Withdrawal(user, withdrawAmount);

    wrappedToken.withdraw(withdrawAmount);
    vm.stopPrank();

    // Check balances after withdrawal
    assertEq(
      wrappedToken.balanceOf(user),
      depositAmount - withdrawAmount,
      "Incorrect wrapped token balance"
    );
    assertEq(
      nativeToken.balanceOf(user),
      INITIAL_BALANCE - depositAmount + withdrawAmount,
      "Incorrect native token balance for user"
    );
    assertEq(
      nativeToken.balanceOf(address(wrappedToken)),
      depositAmount - withdrawAmount,
      "Incorrect native token balance for contract"
    );
  }

  function testFuzz_WithdrawFailsWithInsufficientBalance(uint256 amount) public {
    // Bound the amount to be between 1 and max uint256
    amount = bound(amount, 1, type(uint256).max);

    vm.startPrank(user);
    vm.expectRevert("Insufficient balance");
    wrappedToken.withdraw(amount);
    vm.stopPrank();
  }

  function testFuzz_WithdrawFullAmount(uint256 amount) public {
    // Bound the amount to be between 1 and the user's balance
    amount = bound(amount, 1, INITIAL_BALANCE);

    // First deposit
    vm.startPrank(user);
    nativeToken.approve(address(wrappedToken), amount);
    wrappedToken.deposit(amount);

    // Then withdraw everything
    vm.expectEmit();
    emit Withdrawal(user, amount);

    wrappedToken.withdraw(amount);
    vm.stopPrank();

    // Check balances after withdrawal
    assertEq(wrappedToken.balanceOf(user), 0, "Incorrect wrapped token balance");
    assertEq(
      nativeToken.balanceOf(user), INITIAL_BALANCE, "Incorrect native token balance for user"
    );
    assertEq(
      nativeToken.balanceOf(address(wrappedToken)), 0, "Incorrect native token balance for contract"
    );
  }
}
