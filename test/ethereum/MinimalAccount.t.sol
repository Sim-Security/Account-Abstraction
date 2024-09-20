// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

contract MinimalAccountTest is Test, ZkSyncChainChecker {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    address randomuser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    function setUp() public skipZkSync {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // USDC Mint
    // msg.sender -> MinimalAccount
    // approve some amount
    // USDC contract
    // come from the entrypoint


    /**
     * @dev Tests that the owner of the MinimalAccount can execute commands.
     * The test performs the following steps:
     * 1. Checks the initial balance of the MinimalAccount's USDC tokens.
     * 2. Sets the destination address and value for the execute function call.
     * 3. Encodes the function call data for the ERC20Mock.mint function.
     * 4. Calls the execute function on the MinimalAccount contract.
     * 5. Asserts that the balance of the MinimalAccount's USDC tokens has increased by AMOUNT.
     */
    function testOwnerCanExecuteCommands() public skipZkSync {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    /**
     * @dev Tests that a non-owner of the MinimalAccount cannot execute commands.
     * The test performs the following steps:
     * 1. Checks the initial balance of the MinimalAccount's USDC tokens.
     * 2. Sets the destination address and value for the execute function call.
     * 3. Encodes the function call data for the ERC20Mock.mint function.
     * 4. Calls the execute function on the MinimalAccount contract.
     * 5. Asserts that the transaction reverts with the expected error message.
     */
    function testNonOwnerCannotExecuteCommands() public skipZkSync {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        // Act
        vm.prank(randomuser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    /**
     * @dev Tests the recovery of the signer of a signed user operation.
     * The test performs the following steps:
     * 1. Checks the initial balance of the MinimalAccount's USDC tokens.
     * 2. Sets the destination address and value for the execute function call.
     * 3. Encodes the function call data for the ERC20Mock.mint function.
     * 4. Encodes the execute function call data.
     * 5. Generates a signed user operation using the packedUserOp.generateSignedUserOperation function.
     * 6. Calculates the hash of the user operation using the entryPoint.getUserOpHash function.
     * 7. Recovers the actual signer of the user operation using ECDSA.recover.
     * 8. Asserts that the actual signer is the owner of the MinimalAccount.
     */
    function testRecoverSignedOp() public skipZkSync {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // Act
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    /**
     * @dev Tests the validation of user operations.
     * The test performs the following steps:
     * 1. Checks the initial balance of the MinimalAccount's USDC tokens.
     * 2. Sets the destination address and value for the execute function call.
     * 3. Encodes the function call data for the ERC20Mock.mint function.
     * 4. Encodes the execute function call data.
     * 5. Generates a signed user operation using the packedUserOp.generateSignedUserOperation function.
     * 6. Calculates the hash of the user operation using the entryPoint.getUserOpHash function.
     * 7. Sets the missing account funds value.
     * 8. Calls the validateUserOp function on the MinimalAccount contract.
     * 9. Asserts that the validation data is 0, indicating successful validation.
     */
    function testValidationOfUserOps() public skipZkSync {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    /**
     * @dev Tests that the entry point can execute commands on the MinimalAccount.
     * The test performs the following steps:
     * 1. Checks the initial balance of the MinimalAccount's USDC tokens.
     * 2. Sets the destination address and value for the execute function call.
     * 3. Encodes the function call data for the ERC20Mock.mint function.
     * 4. Encodes the execute function call data.
     * 5. Generates a signed user operation using the packedUserOp.generateSignedUserOperation function.
     * 6. Calls the deal function on the virtual machine to simulate a deal with the MinimalAccount.
     * 7. Creates an array of packed user operations containing the generated user operation.
     * 8. Calls the handleOps function on the entry point contract, passing the array of packed user operations.
     * 9. Asserts that the balance of the MinimalAccount's USDC tokens has increased by AMOUNT.
     */
    function testEntryPointCanExecuteCommands() public skipZkSync {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );

        vm.deal(address(minimalAccount), 1e18);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act
        vm.prank(randomuser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomuser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}