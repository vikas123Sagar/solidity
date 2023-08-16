// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarketplace is ERC721URIStorage, Ownable {
    /**
     * @dev SafeMath library for safe arithmetic operations on uint256.
     */
    using SafeMath for uint256;

    /**
     * @dev Counter library to manage token IDs.
     */
    using Counters for Counters.Counter;

    Counters.Counter private tokenIdCounter;

    /**
    * @dev The listing fee in ether required to list an artwork on the marketplace.
    */
    uint256 private listingFee = 0.05 ether; 

    /**
    * @dev The minimum bid increment in ether required for placing bids in the auction.
    */
    uint256 private minBidIncrement = 0.01 ether;

    // Mapping to store auction details for each token ID
    mapping(uint256 => Auction) private tokenIdToAuction;

        // Struct to hold auction details
    struct Auction {
        address seller; // Address of the seller
        uint256 startingPrice; // Starting price of the auction
        uint256 highestBid; // Highest bid amount in the auction
        address highestBidder; // Address of the highest bidder
        uint256 endTime; // Timestamp when the auction will end
        bool ended; // Flag indicating whether the auction has ended
    }


    /** @dev Emitted when an artwork is listed for auction.
        * @param tokenId The token ID of the artwork.
        * @param startingPrice The starting price of the auction.
    */
    event ArtworkListed(uint256 tokenId, uint256 startingPrice);

    /** @dev Emitted when a new bid is placed on an artwork.
        * @param tokenId The token ID of the artwork.
        * @param bidder The address of the bidder.
        * @param amount The amount of the bid.
    */
    event NewBidPlaced(uint256 tokenId, address bidder, uint256 amount);

    /** @dev Emitted when an auction ends, either with a winner or without bids.
        * @param tokenId The token ID of the artwork.
        * @param winner The address of the winner (or address(0) if no bids).
        * @param amount The amount of the winning bid (or 0 if no bids).
    */
    event AuctionEnded(uint256 tokenId, address winner, uint256 amount);

    /** @dev Constructor to initialize the NFT marketplace contract.
        * @param _name The name of the NFT marketplace.
        * @param _symbol The symbol of the NFT marketplace.
    */
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    /** @dev Modifier to ensure that an auction is active for a given token ID.
        * @param _tokenId The token ID of the artwork.
    */
    modifier onlyActiveAuction(uint256 _tokenId) {
        require(isAuctionActive(_tokenId), "Auction is not active");
        _;
    }

    /** @dev Modifier to ensure that an auction has not ended for a given token ID.
        * @param _tokenId The token ID of the artwork.
    */
    modifier onlyNotEndedAuction(uint256 _tokenId) {
        require(!isAuctionEnded(_tokenId), "Auction has already ended");
        _;
    }

    /** @dev Check if an auction is active for a given token ID.
        * @param _tokenId The token ID of the artwork.
        * @return Whether the auction is currently active.
    */
    function isAuctionActive(uint256 _tokenId) internal view returns (bool) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        return auction.seller != address(0) && !auction.ended;
    }

     /** @dev Check if an auction has ended for a given token ID.
        * @param _tokenId The token ID of the artwork.
        * @return Whether the auction has ended.
    */
    function isAuctionEnded(uint256 _tokenId) internal view returns (bool) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        return auction.ended;
    }

    /** @dev List an artwork for auction.
        * @param _tokenId The token ID of the artwork.
        * @param _startingPrice The starting price of the auction.
        * @param _duration The duration of the auction.
    */
    function listArtwork(uint256 _tokenId, uint256 _startingPrice, uint256 _duration) external payable {
        require(_exists(_tokenId), "Token does not exist");
        require(msg.value == listingFee, "Exact listing fee required");
        require(ownerOf(_tokenId) == msg.sender, "Only the owner can list the artwork");
        require(_duration <= 30 days, "Auction duration is too long (maximum is 30 days)");

        _createAuction(_tokenId, _startingPrice, _duration);

        emit ArtworkListed(_tokenId, _startingPrice);
    }

    /** @dev Create a new auction for an artwork.
        * @param _tokenId The token ID of the artwork.
        * @param _startingPrice The starting price of the auction.
        * @param _duration The duration of the auction in seconds.
    */
    function _createAuction(uint256 _tokenId, uint256 _startingPrice, uint256 _duration) internal {
        tokenIdToAuction[_tokenId] = Auction({
            seller: msg.sender,
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + _duration,
            ended: false
        });
    }

    /** @dev Place a bid on an active and ongoing auction for an artwork.
        * @param _tokenId The token ID of the artwork.
    */
    function placeBid(uint256 _tokenId) external payable onlyActiveAuction(_tokenId) onlyNotEndedAuction(_tokenId) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(msg.value > auction.highestBid.add(minBidIncrement), "Bid amount must be higher than the current highest bid plus the minimum increment");

        _refundPreviousBid(auction.highestBidder, auction.highestBid);

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit NewBidPlaced(_tokenId, msg.sender, msg.value);
    }

    /** @dev Refund the previous highest bidder if there was one.
        * @param _previousBidder The address of the previous highest bidder.
        * @param _previousBidAmount The amount of the previous highest bid.
    */
    function _refundPreviousBid(address _previousBidder, uint256 _previousBidAmount) internal {
        if (_previousBidder != address(0)) {
            payable(_previousBidder).transfer(_previousBidAmount);
        }
    }

    /** @dev End an ongoing auction for an artwork.
        * @param _tokenId The token ID of the artwork.
    */
    function endAuction(uint256 _tokenId) external onlyActiveAuction(_tokenId) onlyOwner {
        Auction storage auction = tokenIdToAuction[_tokenId];
        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            _transfer(auction.seller, auction.highestBidder, _tokenId);

            uint256 royalty = auction.highestBid.mul(5).div(100); // 5% royalty to the artist
            payable(auction.seller).transfer(auction.highestBid.sub(royalty));
            payable(owner()).transfer(royalty);

            emit AuctionEnded(_tokenId, auction.highestBidder, auction.highestBid);
        } else {
            _transfer(owner(), auction.seller, _tokenId); // Return the item to the seller

            // Refund the listing fee
            payable(auction.seller).transfer(listingFee);

            emit AuctionEnded(_tokenId, address(0), 0); // No bids, auction ended
        }
    }

    /** @dev Set the listing fee for listing an artwork.
        * @param _fee The new listing fee amount.
    */
    function setListingFee(uint256 _fee) external onlyOwner {
        listingFee = _fee;
    }

    /** @dev Set the minimum bid increment for placing bids in the auction.
        * @param _increment The new minimum bid increment.
    */
    function setMinBidIncrement(uint256 _increment) external onlyOwner {
        minBidIncrement = _increment;
    }

    /** @dev Get the details of an ongoing auction for a specific artwork.
        * @param _tokenId The token ID of the artwork.
        * @return seller The address of the seller of the artwork.
        * @return startingPrice The starting price of the artwork.
        * @return highestBid The highest bid amount in the auction.
        * @return highestBidder The address of the highest bidder in the auction.
        * @return endTime The timestamp when the auction will end.
        * @return ended Whether the auction has ended.
    */
    function getAuctionDetails(uint256 _tokenId) external view returns (
        address seller,
        uint256 startingPrice,
        uint256 highestBid,
        address highestBidder,
        uint256 endTime,
        bool ended
    ) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        seller = auction.seller;
        startingPrice = auction.startingPrice;
        highestBid = auction.highestBid;
        highestBidder = auction.highestBidder;
        endTime = auction.endTime;
        ended = auction.ended;
    }
}
