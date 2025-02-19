// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployHigherOrLower} from "../../script/DeployHigherOrLower.s.sol";
import {HigherOrLower} from "../../src/HigherOrLower.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "../../script/Interactions.s.sol";

contract HigherOrLowerTest is Test, CodeConstants {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    HigherOrLower public higherOrLower;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 automationUpdateInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;

    address public XPLAYERX = makeAddr("XplayerX");
    address public PLAYER = makeAddr("player");
    address public PLAYER2 = makeAddr("player2");
    address public PLAYER3 = makeAddr("player3");
    address public PLAYER4 = makeAddr("player4");
    address public PLAYER5 = makeAddr("player5");
    address public PLAYER6 = makeAddr("player6");

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 4000 ether;

    function setUp() external {
        DeployHigherOrLower deployer = new DeployHigherOrLower();

        (higherOrLower, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        vm.deal(PLAYER2, STARTING_USER_BALANCE);
        vm.deal(PLAYER3, STARTING_USER_BALANCE);
        vm.deal(PLAYER4, STARTING_USER_BALANCE);
        vm.deal(PLAYER5, STARTING_USER_BALANCE);
        vm.deal(PLAYER6, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        automationUpdateInterval = config.automationUpdateInterval;
        raffleEntranceFee = config.raffleEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(
                subscriptionId,
                LINK_BALANCE
            );
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 TEST GAME
    //////////////////////////////////////////////////////////////*/

    function testGameInitializesInClosedState() public {
        assertEq(
            higherOrLower.getBet_State(),
            uint256(HigherOrLower.Bet_State.CLOSED)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INVEST
    //////////////////////////////////////////////////////////////*/

    function testHigherOrLower_GAME_NOT_OPEN_INVEST() public {
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER);
        higherOrLower.bet{value: 1 ether}(0);
        vm.prank(PLAYER2);
        vm.expectRevert(HigherOrLower.HigherOrLower_GAME_NOT_OPEN.selector);
        higherOrLower.invest();
    }

    function testHigherOrLower_IncorrectInvestmentAmount() public {
        vm.prank(PLAYER);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_IncorrectInvestmentAmount.selector
        );
        higherOrLower.invest();
    }

    function testOwnerInvested() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        assertEq(higherOrLower.getOwnerBalance(), 8 ether);
    }

    function testSeveralTimesOwnerInvested() public {
        vm.deal(PLAYER, 100 ether);
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        assertEq(higherOrLower.getOwnerBalance(), (8 ether * 4));
        assertEq(higherOrLower.getOwners(0), PLAYER);
        assertEq(higherOrLower.getOwners_legth(), 1);
    }

    function testTooManyOwnersInvested() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER4);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER5);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER6);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_OwnersMaximum_Completed.selector
        );
        higherOrLower.invest{value: 5 ether}();
    }

    function testOwneradd() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        assertEq(higherOrLower.getOwners(0), PLAYER);
    }

    function testWithdrawOwner_BalanceIs0_Or_AddressIsnotValid() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER6);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_BalanceIs0_Or_AddressIsnotValid.selector
        );
        higherOrLower.OwnerWithdraw(2 ether);
    }

    function testWithdrawOwner_HigherOrLower_NotEnoughFundsToWithdraw() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_NotEnoughFundsToWithdraw.selector
        );
        higherOrLower.OwnerWithdraw(9 ether);
    }

    function testWithdrawOwner_HigherOrLower_NotEnoughFundsToWithdraw_2()
        public
    {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_NotEnoughFundsToWithdraw.selector
        );
        higherOrLower.OwnerWithdraw(8 ether);
    }

    function testWithdrawOwner_HigherOrLower_NotOPEN() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER2);
        higherOrLower.bet{value: 1 ether}(0);
        vm.prank(PLAYER);
        vm.expectRevert(HigherOrLower.HigherOrLower_GAME_NOT_OPEN.selector);
        higherOrLower.OwnerWithdraw(1 ether);
    }

    function testInvenstBetStateChanged() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        assertEq(higherOrLower.getBet_State(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                 CEO
    //////////////////////////////////////////////////////////////*/

    function testWithdrawOwner_HigherOrLower_NotCEO() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        vm.expectRevert(HigherOrLower.HigherOrLower_NotCEO.selector);
        higherOrLower.ceoWithdraw(1 ether);
    }

    function testXCEOwithDraw() public skipFork {
        // Arrange
        address PLAYER_CEO = higherOrLower.getCEO();
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 5 ether}();

        vm.deal(XPLAYERX, 90 ether);

        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + automationUpdateInterval + 1);
            vm.roll(block.number + 1);

            vm.prank(PLAYER6);

            uint256 xbetAmountX = higherOrLower.getMaxtoBet();
            vm.prank(XPLAYERX);
            higherOrLower.bet{value: xbetAmountX}(0);

            uint256 previousCard = higherOrLower.getPreviousCard();
            uint256 bet = higherOrLower.getBet();

            // Act
            vm.recordLogs();
            higherOrLower.performUpkeep(""); // emits requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            console2.logBytes32(entries[2].topics[1]);
            bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
                uint256(requestId),
                address(higherOrLower)
            );

            // Assert

            console2.log("Bet #", i);

            console2.log("Balance Game", higherOrLower.getBalance());

            vm.prank(PLAYER3);
            console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER_CEO);
            console2.log("Balance CEO", higherOrLower.getCEOWithdrawalAmount());

            console2.log("Max to Bet", higherOrLower.getMaxtoBet());
            console2.log("Bet state: ", higherOrLower.getBet_State());
            if (higherOrLower.getBet_State() == 1) {
                console2.log("--------------CLOSED-----------");
                break;
            }
        }
        console2.log("--------------Withdraw -----------");

        vm.prank(PLAYER_CEO);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_NotEnoughFundsToWithdraw.selector
        );

        higherOrLower.ceoWithdraw(8 ether);
    }

    /*//////////////////////////////////////////////////////////////
                                 BET
    //////////////////////////////////////////////////////////////*/

    function testHigherOrLower_NotEnoughFundsToBet() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_NotEnoughFundsToBet.selector
        );
        higherOrLower.bet(0);
    }

    function testHigherOrLower_TooMuchFundsToBet() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.expectRevert(HigherOrLower.HigherOrLower_TooMuchFundsToBet.selector);
        higherOrLower.bet{value: 3 ether}(0);
    }

    function testHigherOrLower_IncorrectBet() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        console2.log("max to bet", higherOrLower.getMaxtoBet());
        vm.expectRevert(HigherOrLower.HigherOrLower_IncorrectBet.selector);
        higherOrLower.bet{value: 2 ether}(6);
    }

    function testBetData_GAME_NOT_OPEN() public {
        vm.expectRevert(HigherOrLower.HigherOrLower_GAME_NOT_OPEN.selector);
        higherOrLower.bet{value: 2 ether}(0);
    }

    function testBetOngoing() public {
        vm.deal(PLAYER, 5 ether);
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.deal(PLAYER2, 5 ether);
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.deal(PLAYER3, 5 ether);
        vm.prank(PLAYER3);
        higherOrLower.bet{value: 2 ether}(0);
        assertEq(
            higherOrLower.getBet_State(),
            uint256(HigherOrLower.Bet_State.ONGAME)
        );
    }

    function testBetOption() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        higherOrLower.bet{value: 2 ether}(0);
        assertEq(higherOrLower.getBet(), uint256(HigherOrLower.Bet.LOW));
    }

    function testBetPlayer() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER);
        higherOrLower.bet{value: 2 ether}(0);
        assertEq(higherOrLower.getPlayer(), PLAYER);
    }

    function testBetPlayerAmount() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER);
        higherOrLower.bet{value: 2 ether}(0);
        assertEq(higherOrLower.getBetAmount(), 2 ether);
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER);
        higherOrLower.bet{value: 2 ether}(0);
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        higherOrLower.performUpkeep("");

        // Act / Assert
        vm.expectRevert(HigherOrLower.HigherOrLower_GAME_NOT_OPEN.selector);
        vm.prank(PLAYER);
        higherOrLower.bet{value: 2 ether}(0);
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = higherOrLower.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testDataisGood() public {
        // Arrange
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER);
        higherOrLower.bet{value: 2 ether}(0);
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        higherOrLower.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = higherOrLower.checkUpkeep("");
        console2.log("Bet state", higherOrLower.getBet_State());
        console2.log("PLayer", higherOrLower.getPlayer());

        // Assert
        assert(upkeepNeeded);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        HigherOrLower.Bet_State rState = HigherOrLower.Bet_State(
            higherOrLower.getBet_State()
        );
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                HigherOrLower.HigherOrLower_UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        higherOrLower.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
        // Arrange

        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER);
        higherOrLower.bet{value: 1 ether}(0);
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        higherOrLower.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        HigherOrLower.Bet_State rState = HigherOrLower.Bet_State(
            higherOrLower.getBet_State()
        );
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 2); // 0 = open, 1 = calculating
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER);
        higherOrLower.bet{value: 2 ether}(0);
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
        public
        raffleEntered
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            0,
            address(higherOrLower)
        );

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            1,
            address(higherOrLower)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        skipFork
    {
        // Arrange
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 10 ether}();
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER4);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER5);
        higherOrLower.invest{value: 5 ether}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        vm.prank(PLAYER);
        higherOrLower.bet{value: 3 ether}(1);

        uint256 startingTimeStamp = higherOrLower.getLastTimeStamp();
        uint256 previousCard = higherOrLower.getPreviousCard();
        uint256 bet = higherOrLower.getBet();

        // Act
        vm.recordLogs();
        higherOrLower.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[2].topics[1]);
        bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            uint256(requestId),
            address(higherOrLower)
        );

        // Assert
        uint256 newCard = higherOrLower.getPreviousCard();
        bool betWin = false;

        if (previousCard > newCard) {
            if (bet == 0) {
                betWin = true;
            } else {
                betWin = false;
            }
        }
        if (previousCard == newCard) {
            if (bet == 1) {
                betWin = true;
            } else {
                betWin = false;
            }
        }
        if (previousCard < newCard) {
            if (bet == 2) {
                betWin = true;
            } else {
                betWin = false;
            }
        }

        if (betWin) {
            uint256 winnerBalance = PLAYER.balance;
            uint256 endingTimeStamp = higherOrLower.getLastTimeStamp();
            assert(winnerBalance == 16);
            assert(endingTimeStamp > startingTimeStamp);
            vm.prank(PLAYER3);
            assert(higherOrLower.getOwnerBalance() == 0 ether);
        } else {
            uint256 endingTimeStamp = higherOrLower.getLastTimeStamp();
            uint256 winnerBalance = PLAYER.balance;
            assert(winnerBalance == 7 ether);
            vm.prank(PLAYER2);
            uint256 mostOwnerBalance = higherOrLower.getOwnerBalance();
            assert(mostOwnerBalance > 0 ether);
            vm.prank(PLAYER3);
            assert(higherOrLower.getOwnerBalance() > 0 ether);
            vm.prank(PLAYER4);
            assert(higherOrLower.getOwnerBalance() > 0 ether);
            vm.prank(PLAYER5);
            uint256 otherOwnerBalance = higherOrLower.getOwnerBalance();
            assert(otherOwnerBalance > 0 ether);

            assert(mostOwnerBalance > otherOwnerBalance);

            assert(endingTimeStamp > startingTimeStamp);
        }
    }

    function testX() public skipFork {
        // Arrange
        address PLAYER_CEO = higherOrLower.getCEO();
        vm.deal(PLAYER3, 18 ether);
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER4);
        higherOrLower.invest{value: 5 ether}();
        vm.deal(PLAYER5, 18 ether);
        vm.prank(PLAYER5);
        higherOrLower.invest{value: 5 ether}();
        vm.deal(PLAYER6, 15 ether);
        vm.prank(PLAYER6);
        higherOrLower.invest{value: 5 ether}();

        vm.deal(XPLAYERX, 90 ether);

        for (uint256 i = 0; i < 50; i++) {
            vm.warp(block.timestamp + automationUpdateInterval + 1);
            vm.roll(block.number + 1);

            console2.log("Bet state: ", higherOrLower.getBet_State());
            vm.prank(PLAYER6);
            console2.log(
                "Balance owner 6 final ",
                higherOrLower.getOwnerBalance()
            );

            vm.prank(XPLAYERX);
            uint256 xbetAmountX = higherOrLower.getMaxtoBet();
            vm.prank(XPLAYERX);
            higherOrLower.bet{value: xbetAmountX}(0);

            uint256 previousCard = higherOrLower.getPreviousCard();
            uint256 bet = higherOrLower.getBet();

            // Act
            vm.recordLogs();
            higherOrLower.performUpkeep(""); // emits requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            console2.logBytes32(entries[2].topics[1]);
            bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
                uint256(requestId),
                address(higherOrLower)
            );

            // Assert
            uint256 newCard = higherOrLower.getPreviousCard();
            bool betWin = false;

            if (previousCard > newCard) {
                if (bet == 0) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard == newCard) {
                if (bet == 1) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard < newCard) {
                if (bet == 2) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }

            if (betWin) {} else {}
            console2.log("Bet #", i);

            console2.log("Balance player", XPLAYERX.balance);
            vm.prank(PLAYER2);
            console2.log("Balance owner 2", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER3);
            console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER4);
            console2.log("Balance owner 4 ", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER5);
            console2.log("Balance owner 5 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER6);
            console2.log("Balance owner 6 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER_CEO);

            console2.log(
                "Balance CEO ",
                higherOrLower.getCEOWithdrawalAmount()
            );

            console2.log("Max to Bet", higherOrLower.getMaxtoBet());
            if (higherOrLower.getBet_State() == 1) {
                break;
            }
        }
        console2.log("Balance Contract", higherOrLower.getBalance());
    }

    function testXMoreMoney() public skipFork {
        // Arrange
        address PLAYER_CEO = higherOrLower.getCEO();
        vm.deal(PLAYER3, 18 ether);
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 9 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER4);
        higherOrLower.invest{value: 5 ether}();
        vm.deal(PLAYER5, 18 ether);
        vm.prank(PLAYER5);
        higherOrLower.invest{value: 5 ether}();
        vm.deal(PLAYER6, 15 ether);
        vm.prank(PLAYER6);
        higherOrLower.invest{value: 15 ether}();

        vm.deal(XPLAYERX, 90 ether);

        for (uint256 i = 0; i < 50; i++) {
            vm.warp(block.timestamp + automationUpdateInterval + 1);
            vm.roll(block.number + 1);

            console2.log("Bet state: ", higherOrLower.getBet_State());
            vm.prank(PLAYER6);
            console2.log(
                "Balance owner 6 final ",
                higherOrLower.getOwnerBalance()
            );

            vm.prank(XPLAYERX);
            uint256 xbetAmountX = higherOrLower.getMaxtoBet();
            vm.prank(XPLAYERX);
            higherOrLower.bet{value: xbetAmountX}(0);

            uint256 previousCard = higherOrLower.getPreviousCard();
            uint256 bet = higherOrLower.getBet();

            // Act
            vm.recordLogs();
            higherOrLower.performUpkeep(""); // emits requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            console2.logBytes32(entries[2].topics[1]);
            bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
                uint256(requestId),
                address(higherOrLower)
            );

            // Assert
            uint256 newCard = higherOrLower.getPreviousCard();
            bool betWin = false;

            if (previousCard > newCard) {
                if (bet == 0) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard == newCard) {
                if (bet == 1) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard < newCard) {
                if (bet == 2) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }

            if (betWin) {} else {}
            console2.log("Bet #", i);

            console2.log("Balance player", XPLAYERX.balance);
            vm.prank(PLAYER2);
            console2.log("Balance owner 2", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER3);
            console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER4);
            console2.log("Balance owner 4 ", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER5);
            console2.log("Balance owner 5 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER6);
            console2.log("Balance owner 6 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER_CEO);

            console2.log(
                "Balance CEO ",
                higherOrLower.getCEOWithdrawalAmount()
            );

            console2.log("Max to Bet", higherOrLower.getMaxtoBet());
            if (higherOrLower.getBet_State() == 1) {
                break;
            }
        }
    }

    function testXOneOwner() public skipFork {
        // Arrange
        address PLAYER_CEO = higherOrLower.getCEO();

        vm.deal(PLAYER3, 18 ether);
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 5 ether}();

        vm.deal(XPLAYERX, 90 ether);

        for (uint256 i = 0; i < 50; i++) {
            vm.warp(block.timestamp + automationUpdateInterval + 1);
            vm.roll(block.number + 1);

            vm.prank(PLAYER6);

            uint256 xbetAmountX = higherOrLower.getMaxtoBet();
            vm.prank(XPLAYERX);
            higherOrLower.bet{value: xbetAmountX}(0);

            uint256 previousCard = higherOrLower.getPreviousCard();
            uint256 bet = higherOrLower.getBet();

            // Act
            vm.recordLogs();
            higherOrLower.performUpkeep(""); // emits requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            console2.logBytes32(entries[2].topics[1]);
            bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
                uint256(requestId),
                address(higherOrLower)
            );

            // Assert
            uint256 newCard = higherOrLower.getPreviousCard();
            bool betWin = false;

            if (previousCard > newCard) {
                if (bet == 0) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard == newCard) {
                if (bet == 1) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard < newCard) {
                if (bet == 2) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }

            if (betWin) {} else {}
            console2.log("Bet #", i);
            console2.log("Balance Game", higherOrLower.getBalance());

            console2.log("Balance player", XPLAYERX.balance);
            vm.prank(PLAYER2);
            console2.log("Balance owner 2", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER3);
            console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER4);
            console2.log("Balance owner 4 ", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER5);
            console2.log("Balance owner 5 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER6);
            console2.log("Balance owner 6 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER_CEO);

            console2.log(
                "Balance CEO ",
                higherOrLower.getCEOWithdrawalAmount()
            );

            console2.log("Max to Bet", higherOrLower.getMaxtoBet());
            console2.log("Bet state: ", higherOrLower.getBet_State());
            if (higherOrLower.getBet_State() == 1) {
                break;
            }
        }
    }

    // function testX() public skipFork {

    function testXInvestAfterClosed() public skipFork {
        // Arrange
        address PLAYER_CEO = higherOrLower.getCEO();
        vm.deal(PLAYER3, 18 ether);
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 5 ether}();

        vm.deal(XPLAYERX, 90 ether);

        for (uint256 i = 0; i < 50; i++) {
            vm.warp(block.timestamp + automationUpdateInterval + 1);
            vm.roll(block.number + 1);

            vm.prank(PLAYER6);

            uint256 xbetAmountX = higherOrLower.getMaxtoBet();
            vm.prank(XPLAYERX);
            higherOrLower.bet{value: xbetAmountX}(0);

            uint256 previousCard = higherOrLower.getPreviousCard();
            uint256 bet = higherOrLower.getBet();

            // Act
            vm.recordLogs();
            higherOrLower.performUpkeep(""); // emits requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            console2.logBytes32(entries[2].topics[1]);
            bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
                uint256(requestId),
                address(higherOrLower)
            );

            // Assert
            uint256 newCard = higherOrLower.getPreviousCard();
            bool betWin = false;

            if (previousCard > newCard) {
                if (bet == 0) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard == newCard) {
                if (bet == 1) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard < newCard) {
                if (bet == 2) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }

            if (betWin) {} else {}
            console2.log("Bet #", i);
            console2.log("Balance Game", higherOrLower.getBalance());

            console2.log("Balance player", XPLAYERX.balance);
            vm.prank(PLAYER2);
            console2.log("Balance owner 2", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER3);
            console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER4);
            console2.log("Balance owner 4 ", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER5);
            console2.log("Balance owner 5 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER6);
            console2.log("Balance owner 6 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER_CEO);

            console2.log(
                "Balance CEO ",
                higherOrLower.getCEOWithdrawalAmount()
            );

            console2.log("Max to Bet", higherOrLower.getMaxtoBet());
            console2.log("Bet state: ", higherOrLower.getBet_State());
            if (higherOrLower.getBet_State() == 1) {
                console2.log("--------------New Investion -----------");

                vm.deal(PLAYER3, 5 ether);
                vm.prank(PLAYER3);
                higherOrLower.invest{value: 5 ether}();
            }
        }
    }

    function testXOwnerwithDraw() public skipFork {
        // Arrange
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 5 ether}();
        address PLAYER_CEO = higherOrLower.getCEO();

        vm.deal(XPLAYERX, 90 ether);

        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + automationUpdateInterval + 1);
            vm.roll(block.number + 1);

            vm.prank(PLAYER6);

            uint256 xbetAmountX = higherOrLower.getMaxtoBet();
            vm.prank(XPLAYERX);
            higherOrLower.bet{value: xbetAmountX}(0);

            uint256 previousCard = higherOrLower.getPreviousCard();
            uint256 bet = higherOrLower.getBet();

            // Act
            vm.recordLogs();
            higherOrLower.performUpkeep(""); // emits requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            console2.logBytes32(entries[2].topics[1]);
            bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
                uint256(requestId),
                address(higherOrLower)
            );

            // Assert

            console2.log("Bet #", i);
            console2.log("Balance Game", higherOrLower.getBalance());

            console2.log("Balance player", XPLAYERX.balance);
            vm.prank(PLAYER2);
            console2.log("Balance owner 2", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER3);
            console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER4);
            console2.log("Balance owner 4 ", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER5);
            console2.log("Balance owner 5 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER6);
            console2.log("Balance owner 6 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER_CEO);

            console2.log(
                "Balance CEO ",
                higherOrLower.getCEOWithdrawalAmount()
            );

            console2.log("Max to Bet", higherOrLower.getMaxtoBet());
            console2.log("Bet state: ", higherOrLower.getBet_State());
            if (higherOrLower.getBet_State() == 1) {
                console2.log("--------------CLOSED-----------");
                break;
            }
            if (i == 5) {
                console2.log("--------------Withdraw -----------");
                vm.prank(PLAYER3);
                higherOrLower.OwnerWithdraw(3 ether);
                console2.log("Balance owner xxx", PLAYER3.balance);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 SUBTRATION TEST
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This test only work if you comment the following in the contract
     * 
     *   /* if (msg.value < INVEST_AMOUNT) {
            revert HigherOrLower_IncorrectInvestmentAmount();
        }*/

    /*if (msg.value < MIN_BET) {
            revert HigherOrLower_NotEnoughFundsToBet();
        }
        if (msg.value > s_MaxBet) {
            revert HigherOrLower_TooMuchFundsToBet();
        }
     */

    /*function testXGamePay() public skipFork {
        // Arrange
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 0.8 ether}();
        vm.prank(PLAYER3);
        higherOrLower.invest{value: 0.5 ether}();
        vm.prank(PLAYER4);
        higherOrLower.invest{value: 1.1 ether}();
        vm.prank(PLAYER5);
        higherOrLower.invest{value: 0.5 ether}();
        vm.prank(PLAYER6);
        higherOrLower.invest{value: 2 ether}();
        address PLAYER_CEO = higherOrLower.getCEO();

        vm.deal(XPLAYERX, 90 ether);

        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        vm.prank(PLAYER6);

        uint256 xbetAmountX = higherOrLower.getMaxtoBet();
        vm.prank(XPLAYERX);
        higherOrLower.bet{value: 2.5 ether}(0);

        uint256 previousCard = higherOrLower.getPreviousCard();
        uint256 bet = higherOrLower.getBet();

        // Act
        vm.recordLogs();
        higherOrLower.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[2].topics[1]);
        bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            uint256(requestId),
            address(higherOrLower)
        );

        // Assert

        console2.log("Balance Game", higherOrLower.getBalance());

        console2.log("Balance player", XPLAYERX.balance);
        vm.prank(PLAYER2);
        console2.log("Balance owner 2", higherOrLower.getOwnerBalance());

        vm.prank(PLAYER3);
        console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

        vm.prank(PLAYER4);
        console2.log("Balance owner 4 ", higherOrLower.getOwnerBalance());

        vm.prank(PLAYER5);
        console2.log("Balance owner 5 ", higherOrLower.getOwnerBalance());
        vm.prank(PLAYER6);
        console2.log("Balance owner 6 ", higherOrLower.getOwnerBalance());
        vm.prank(PLAYER_CEO);

        console2.log("Balance CEO ", higherOrLower.getCEOWithdrawalAmount());

        console2.log("Max to Bet", higherOrLower.getMaxtoBet());
        console2.log("Bet state: ", higherOrLower.getBet_State());
        if (higherOrLower.getBet_State() == 1) {
            console2.log("--------------CLOSED-----------");
        }
    }*/
}
