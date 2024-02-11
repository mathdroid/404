// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/examples/ExampleERC404.sol";
import "../src/mocks/MinimalERC404.sol";
import {IERC404} from "../src/interfaces/IERC404.sol";
import "../src/ERC404.sol";

// deployExampleERC404
// deployExampleERC404WithSomeTokensTransferredToRandomAddress
contract Erc404Test is Test {
    ExampleERC404 public simpleContract_;

    string name_ = "Example";
    string symbol_ = "EXM";
    uint8 decimals_ = 18;
    uint256 maxTotalSupplyNft_ = 100;
    uint256 units_ = 10 ** decimals_;

    address initialOwner_ = address(0x1);
    address initialMintRecipient_ = address(0x2);

    ///////////////////////////// deployMinimalERC404()
    function setUp() public {
        simpleContract_ =
            new ExampleERC404(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);
    }

    function test_initializeSimple() public {
        assertEq(simpleContract_.name(), name_);
        assertEq(simpleContract_.symbol(), symbol_);
        assertEq(simpleContract_.decimals(), decimals_);
        assertEq(simpleContract_.owner(), initialOwner_);
    }

    function test_initialMint() public {
        // initial balance is 100 ** decimals ERC20, but 0 NFT
        // ExampleERC404.sol:L18
        assertEq(simpleContract_.balanceOf(initialMintRecipient_), maxTotalSupplyNft_ * units_);
        assertEq(simpleContract_.owned(initialMintRecipient_).length, 0);
        // NFT minted count should be 0.
        assertEq(simpleContract_.erc721TotalSupply(), 0);
        // Total supply of ERC20s tokens should be equal to the initial mint recipient's balance.
        assertEq(simpleContract_.totalSupply(), maxTotalSupplyNft_ * units_);
        assertEq(simpleContract_.erc20TotalSupply(), maxTotalSupplyNft_ * units_);
    }

    function test_initialWhitelist() public {
        // Initializes the whitelist with the initial mint recipient
        assertTrue(simpleContract_.whitelist(initialMintRecipient_));
    }

    ///////////////////////////// deployExampleERC404WithSomeTokensTransferredToRandomAddress()
    function test_tokenTransfer(uint8 nftToTransfer, address randomAddress) public {
        vm.assume(nftToTransfer <= 100);
        vm.assume(randomAddress != address(0));

        // Transfer some tokens to a non-whitelisted wallet to generate the NFTs.
        vm.prank(initialMintRecipient_);
        simpleContract_.transfer(randomAddress, nftToTransfer * units_);

        // Returns the correct total supply
        assertEq(simpleContract_.erc721TotalSupply(), nftToTransfer);
        assertEq(simpleContract_.totalSupply(), maxTotalSupplyNft_ * units_);
        assertEq(simpleContract_.erc20TotalSupply(), maxTotalSupplyNft_ * units_);

        // Reverts if the token ID is 0
        vm.expectRevert(IERC404.NotFound.selector);
        simpleContract_.ownerOf(0);

        // Reverts if the token ID is `nftToTransfer + 1` (does not exist)
        vm.expectRevert(IERC404.NotFound.selector);
        simpleContract_.ownerOf(nftToTransfer + 1);

        for (uint8 i = 1; i <= nftToTransfer; i++) {
            assertEq(simpleContract_.ownerOf(i), randomAddress);
        }
    }
}

// deployMinimalERC404
contract Erc404MinimalTest is Test {
    MinimalERC404 public minimalContract_;

    string name_ = "Example";
    string symbol_ = "EXM";
    uint8 decimals_ = 18;
    uint256 units_ = 10 ** decimals_;
    uint256 maxTotalSupplyNft_ = 100;
    uint256 maxTotalSupplyCoin_ = maxTotalSupplyNft_ * units_;

    address initialOwner_ = address(0x1);

    event ERC721Transfer(address indexed from, address indexed to, uint256 indexed id);
    event ERC20Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        minimalContract_ = new MinimalERC404(name_, symbol_, decimals_, initialOwner_);
    }

    function test_initializeMinimal() public {
        assertEq(minimalContract_.name(), name_);
        assertEq(minimalContract_.symbol(), symbol_);
        assertEq(minimalContract_.decimals(), decimals_);
        assertEq(minimalContract_.owner(), initialOwner_);
    }

    function test_mintFullSupply_20_721(address recipient) public {
        vm.assume(recipient != address(0));

        // Owner mints the full supply of ERC20 tokens (with the corresponding ERC721 tokens minted as well)
        vm.prank(initialOwner_);
        minimalContract_.mintERC20(recipient, maxTotalSupplyCoin_, true);

        // Expect the total supply to be equal to the max total supply
        assertEq(minimalContract_.totalSupply(), maxTotalSupplyCoin_);
        assertEq(minimalContract_.erc20TotalSupply(), maxTotalSupplyCoin_);

        // Expect the minted count to be equal to the max total supply
        assertEq(minimalContract_.erc721TotalSupply(), maxTotalSupplyNft_);
    }

    function test_mintFullSupply_20(address recipient) public {
        vm.assume(recipient != address(0));

        // Owner mints the full supply of ERC20 tokens only
        vm.prank(initialOwner_);
        minimalContract_.mintERC20(recipient, maxTotalSupplyCoin_, false);

        // Expect the total supply to be equal to the max total supply
        assertEq(minimalContract_.totalSupply(), maxTotalSupplyCoin_);
        assertEq(minimalContract_.erc20TotalSupply(), maxTotalSupplyCoin_);

        // Expect the minted count to be equal to 0
        assertEq(minimalContract_.erc721TotalSupply(), 0);
    }

    function test_erc721Storage_mintFrom0(uint8 nftQty, address recipient) public {
        vm.assume(nftQty < maxTotalSupplyNft_);
        vm.assume(recipient != address(0) && recipient != initialOwner_ && recipient != address(minimalContract_));

        // Total supply should be 0
        assertEq(minimalContract_.erc721TotalSupply(), 0);

        // Expect the contract's bank to be empty
        assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
        assertEq(minimalContract_.erc721TokensBankedInQueue(), 0);

        uint256 value = nftQty * units_;

        // mint at the bottom, setup expected events first

        // expect 1 erc20 transfer event
        // Check for ERC20Transfer mint events (from 0x0 to the recipient)
        vm.expectEmit(false, false, false, true);
        emit ERC20Transfer(address(0), recipient, value);

        // expect multiple erc721 transfers
        for (uint8 i = 1; i <= nftQty; i++) {
            // Check for ERC721Transfer mint events (from 0x0 to the recipient)
            vm.expectEmit(true, true, true, true);
            emit ERC721Transfer(address(0), recipient, i);
        }

        // mint as owner
        vm.prank(initialOwner_);
        minimalContract_.mintERC20(recipient, value, true);

        // nft supply and balance
        assertEq(minimalContract_.erc721TotalSupply(), nftQty);
        assertEq(minimalContract_.erc721BalanceOf(recipient), nftQty);

        // coin supply and balance
        assertEq(minimalContract_.erc20TotalSupply(), value);
        assertEq(minimalContract_.erc20BalanceOf(recipient), value);

        assertEq(minimalContract_.totalSupply(), value);
        assertEq(minimalContract_.balanceOf(recipient), value);
    }

    function test_erc721Storage_storeInBankOnBurn(uint8 nftQty, address recipient1, address recipient2) public {
        // TODO - handle recipient1 = recipient2
        vm.assume(recipient1 != recipient2);

        vm.assume(nftQty > 0 && nftQty < maxTotalSupplyNft_);
        vm.assume(recipient1 != address(0) && recipient1 != initialOwner_ && recipient1 != address(minimalContract_));
        vm.assume(recipient2 != address(0) && recipient2 != initialOwner_ && recipient2 != address(minimalContract_));
        vm.assume(!minimalContract_.whitelist(recipient1) && !minimalContract_.whitelist(recipient2));

        // Total supply should be 0
        assertEq(minimalContract_.erc721TotalSupply(), 0);

        // Expect the contract's bank to be empty
        assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
        assertEq(minimalContract_.erc721TokensBankedInQueue(), 0);

        uint256 value = nftQty * units_;

        // mint as owner
        vm.prank(initialOwner_);
        minimalContract_.mintERC20(recipient1, value, true);

        uint256 fractionalValueToTransferErc20 = units_ / 10;

        // setup expected events
        // ERC20 transfer
        vm.expectEmit(false, false, false, false);
        emit ERC20Transfer(recipient1, recipient2, fractionalValueToTransferErc20);

        // // ERC721 burn (last token id = nftQty)
        vm.expectEmit(false, false, false, false);
        emit ERC721Transfer(recipient1, address(0), nftQty);

        vm.prank(recipient1);
        minimalContract_.transfer(recipient2, fractionalValueToTransferErc20);

        // erc721 total supply stays the same
        assertEq(minimalContract_.erc721TotalSupply(), nftQty);

        // owner of NFT id nftQty should be 0x0
        vm.expectRevert(IERC404.NotFound.selector);
        minimalContract_.ownerOf(nftQty);

        // sender nft balance is nftQty - 1
        assertEq(minimalContract_.erc721BalanceOf(recipient1), nftQty - 1);

        // contract balance = 0
        // contract bank = 1 nft
        assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
        assertEq(minimalContract_.erc721TokensBankedInQueue(), 1);
    }

    function test_erc721Storage_retrieveFromBank(uint8 nftQty, address recipient1, address recipient2) public {
        // TODO - handle recipient1 = recipient2
        vm.assume(recipient1 != recipient2);

        vm.assume(nftQty > 0 && nftQty < maxTotalSupplyNft_);
        vm.assume(recipient1 != address(0) && recipient1 != initialOwner_ && recipient1 != address(minimalContract_));
        vm.assume(recipient2 != address(0) && recipient2 != initialOwner_ && recipient2 != address(minimalContract_));
        vm.assume(!minimalContract_.whitelist(recipient1) && !minimalContract_.whitelist(recipient2));

        uint256 value = nftQty * units_;

        // mint as owner
        vm.prank(initialOwner_);
        minimalContract_.mintERC20(recipient1, value, true);

        uint256 fractionalValueToTransferErc20 = units_ / 10;
        vm.prank(recipient1);
        minimalContract_.transfer(recipient2, fractionalValueToTransferErc20);

        assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
        assertEq(minimalContract_.erc721TokensBankedInQueue(), 1);

        // reconstitute
        // expected events
        vm.expectEmit(false, false, false, false);
        emit ERC20Transfer(recipient2, recipient1, fractionalValueToTransferErc20);

        vm.expectEmit(false, false, false, false);
        emit ERC721Transfer(address(0), recipient1, nftQty);

        // tx
        vm.prank(recipient2);
        minimalContract_.transfer(recipient1, fractionalValueToTransferErc20);

        // Original sender's ERC20 balance should be nftQty * units
        // The owner of NFT `nftQty` should be the original sender's address
        assertEq(minimalContract_.erc20BalanceOf(recipient1), nftQty * units_);
        assertEq(minimalContract_.ownerOf(nftQty), recipient1);

        // The sender's NFT balance should be 10
        // The contract's NFT balance should be 0
        // The contract's bank should contain 0 NFTs
        assertEq(minimalContract_.erc721BalanceOf(recipient1), nftQty);
        assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
        assertEq(minimalContract_.erc721TokensBankedInQueue(), 0);
    }
}

contract ERC404TransferLogicTest is Test {
    ExampleERC404 public simpleContract_;

    string name_ = "Example";
    string symbol_ = "EXM";
    uint8 decimals_ = 18;
    uint256 maxTotalSupplyNft_ = 100;
    uint256 units_ = 10 ** decimals_;

    address initialOwner_ = address(0x1);
    address initialMintRecipient_ = address(0x2);

    // alice is initial sender for all this test;
    address alice = address(0xa);
    address bob = address(0xb);

    function setUp() public {
        simpleContract_ =
            new ExampleERC404(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);

        // Add the owner to the whitelist
        vm.prank(initialOwner_);
        simpleContract_.setWhitelist(initialOwner_, true);

        vm.prank(initialMintRecipient_);
        simpleContract_.transfer(alice, maxTotalSupplyNft_ * units_);
    }
    //////// Fractional transfers (moving less than 1 full token) that trigger ERC721 transfers

    function test_erc20TransferTriggering721Transfer_fractional_receiverGain() public {
        // Bob starts with 0.9 tokens
        uint256 bobInitialBalance = units_ * 9 / 10;
        vm.prank(alice);
        simpleContract_.transfer(bob, bobInitialBalance);

        uint256 aliceInitialBalance = simpleContract_.balanceOf(alice);
        uint256 aliceInitialNftBalance = (simpleContract_.erc721BalanceOf(alice));

        // Ensure that the receiver has 0.9 tokens and 0 NFTs.
        assertEq(simpleContract_.balanceOf(bob), bobInitialBalance);
        assertEq(simpleContract_.erc20BalanceOf(bob), bobInitialBalance);
        assertEq(simpleContract_.erc721BalanceOf(bob), 0);

        uint256 fractionalValueToTransferErc20 = units_ / 10;
        vm.prank(alice);

        simpleContract_.transfer(bob, fractionalValueToTransferErc20);

        // Verify ERC20 balances after transfer
        assertEq(simpleContract_.balanceOf(alice), aliceInitialBalance - fractionalValueToTransferErc20);
        assertEq(simpleContract_.balanceOf(bob), bobInitialBalance + fractionalValueToTransferErc20);

        // Verify ERC721 balances after transfer
        // Assuming the receiver should have gained 1 NFT due to the transfer completing a whole token
        assertEq(simpleContract_.erc721BalanceOf(alice), aliceInitialNftBalance);
        assertEq(simpleContract_.erc721BalanceOf(bob), 1);
    }

    function test_erc20TransferTriggering721Transfer_fractional_senderLose() public {
        uint256 aliceStartingBalanceErc20 = simpleContract_.balanceOf(alice);
        uint256 aliceStartingBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

        uint256 bobStartingBalanceErc20 = simpleContract_.balanceOf(bob);
        uint256 bobStartingBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

        assertEq(aliceStartingBalanceErc20, maxTotalSupplyNft_ * units_);
        // Sender starts with 100 tokens and sends 0.1, resulting in the loss of 1 NFT but no NFT transfer to the receiver.
        uint256 initialFractionalAmount = units_ / 10;
        vm.prank(alice);
        simpleContract_.transfer(bob, initialFractionalAmount);

        // Post-transfer balances
        uint256 aliceAfterBalanceErc20 = simpleContract_.balanceOf(alice);
        uint256 aliceAfterBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

        uint256 bobAfterBalanceErc20 = simpleContract_.balanceOf(bob);
        uint256 bobAfterBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

        assertEq(aliceAfterBalanceErc20, aliceStartingBalanceErc20 - initialFractionalAmount);
        assertEq(bobAfterBalanceErc20, bobStartingBalanceErc20 + initialFractionalAmount);

        // Verify ERC721 balances after transfer
        // Assuming the sender should lose 1 NFT due to the transfer causing a loss of a whole token.
        // Sender loses an NFT
        assertEq(aliceAfterBalanceErc721, aliceStartingBalanceErc721 - 1);
        // No NFT gain for the receiver
        assertEq(bobAfterBalanceErc721, bobStartingBalanceErc721);
        // Contract gains an NFT (it's stored in the contract in this scenario).
        // TODO - Verify this with the contract's balance.
    }

    //////// Moving one or more full tokens
    function test_erc20TransferTriggering721Transfer_whole_noFractionalImpact() public {
        // Transfers whole tokens without fractional impact correctly
        uint256 aliceStartingBalanceErc20 = simpleContract_.balanceOf(alice);
        uint256 aliceStartingBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

        uint256 bobStartingBalanceErc20 = simpleContract_.balanceOf(bob);
        uint256 bobStartingBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

        // Transfer 2 whole tokens
        uint256 erc721TokensToTransfer = 2;
        uint256 valueToTransferERC20 = erc721TokensToTransfer * units_;

        vm.prank(alice);
        simpleContract_.transfer(bob, valueToTransferERC20);

        // Post-transfer balances
        uint256 aliceAfterBalanceErc20 = simpleContract_.balanceOf(alice);
        uint256 aliceAfterBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

        uint256 bobAfterBalanceErc20 = simpleContract_.balanceOf(bob);
        uint256 bobAfterBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

        // Verify ERC20 balances after transfer
        assertEq(aliceAfterBalanceErc20, aliceStartingBalanceErc20 - valueToTransferERC20);
        assertEq(bobAfterBalanceErc20, bobStartingBalanceErc20 + valueToTransferERC20);

        // Verify ERC721 balances after transfer - Assuming 2 NFTs should have been transferred
        assertEq(aliceAfterBalanceErc721, aliceStartingBalanceErc721 - erc721TokensToTransfer);
        assertEq(bobAfterBalanceErc721, bobStartingBalanceErc721 + erc721TokensToTransfer);
    }

    function test_erc20TransferTriggering721Transfer_whole_3_2_sender99_1_recipient_0_9() public {
        // Handles the case of sending 3.2 tokens where the sender started out with 99.1 tokens and the receiver started with 0.9 tokens
        uint256 aliceStartingBalanceErc20 = simpleContract_.balanceOf(alice);
        uint256 aliceStartingBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

        uint256 bobStartingBalanceErc20 = simpleContract_.balanceOf(bob);
        uint256 bobStartingBalanceErc721 = simpleContract_.erc721BalanceOf(bob);
    }
}
