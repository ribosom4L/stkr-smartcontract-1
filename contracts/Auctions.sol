// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/SafeMath.sol";

// TODO: move Context to an independent file
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract ProviderContract {
    function isProvider(address addr) public view virtual returns (bool);
}

contract Auctions is Context {
    using SafeMath for uint256;

    enum AuctionStatus {OnGoing, Completed}

    struct Auction {
        uint256 processingFee; // fee for request an auction
        uint256 endTime; // timestamp. after that time auction will be closed to new bids
        Winner winner; // the lowest bid
        mapping (address => uint256) bids; // bidders and their bid amounts
    }

    struct Winner {
        uint256 bidAmount;
        address bidder;
    }

    Auction[] private _auctions;
    ProviderContract private _providerContract;

    modifier onlyProvider() {
        require(_providerContract.isProvider(_msgSender()));
        _;
    }

    // TODO: events

    constructor(
      ProviderContract providerContract
    ) public {
      _providerContract = providerContract;
    }

    function startAuction(
      uint256 processingFee, 
      uint256 period // that period of time (in days) auction will long
      ) external {
        // TODO: validations

        Auction memory auction;
        auction.processingFee = processingFee;
        auction.endTime = block.timestamp.add(period.mul(1 days));
        _auctions.push(auction);
    }

    function bid(
        uint256 auctionIndex,
        uint256 processingFee
    )
    external
    onlyProvider {
        // TODO: validations
        // TODO: if auction is still active
        Auction storage auction = _auctions[auctionIndex];
        auction.bids[_msgSender()] = processingFee;
        require(processingFee <= auction.processingFee, "You need to offer less than or equal to requester's budget.");
        if (auction.winner.bidAmount > 0) {
            require(processingFee < auction.winner.bidAmount, "You need to offer less than the lowest bid.");
        }
        auction.winner.bidAmount = processingFee;
        auction.winner.bidder = _msgSender();
    }

    function auctionDetails(uint256 auctionIndex)
        public
        view
        returns (
            uint256 processingFee,
            AuctionStatus status,
            uint256 bestBidAmount,
            address bestBidder
        ) {
            Auction memory auction = _auctions[auctionIndex];
            processingFee = auction.processingFee;
            if (block.timestamp > auction.endTime) {
                status = AuctionStatus.Completed; // completed auction
            } else {
                status = AuctionStatus.OnGoing; // ongoing auction
            }
            bestBidAmount = auction.winner.bidAmount;
            bestBidder = auction.winner.bidder;
    }
}
