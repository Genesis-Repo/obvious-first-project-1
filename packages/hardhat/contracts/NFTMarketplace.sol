// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract NFTMarketplace is ERC721Enumerable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    address public owner;
    uint256 public royaltyFee; // Royalty fee in percentage

    mapping(uint256 => uint256) private _tokenRoyalties; // Royalty fee for each token
    mapping(uint256 => address) private _tokenCreators; // Creator of each token
    EnumerableMap.UintToAddressMap private _tokenRoyaltyRecipients; // Royalty recipients for each token
    mapping(uint256 => uint256) private _tokenPrices; // Price of each token
    mapping(uint256 => address) private _tokenHighestBidder; // Address of the highest bidder for each token
    mapping(uint256 => uint256) private _tokenHighestBid; // Highest bid amount for each token

    event RoyaltySet(uint256 indexed tokenId, uint256 royaltyFee, address royaltyRecipient);
    event NFTSold(address buyer, uint256 tokenId, uint256 price);
    event NewBid(address bidder, uint256 tokenId, uint256 amount);
    event AuctionEnded(uint256 tokenId, address winner, uint256 amount);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        owner = msg.sender;
        royaltyFee = 5; // 5% royalty fee by default
    }

    function setRoyalty(uint256 tokenId, uint256 royaltyFee, address royaltyRecipient) public {
        require(_exists(tokenId), "Token does not exist");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");

        _tokenRoyalties[tokenId] = royaltyFee;
        _tokenRoyaltyRecipients.set(tokenId, royaltyRecipient);

        emit RoyaltySet(tokenId, royaltyFee, royaltyRecipient);
    }

    function buyNFT(uint256 tokenId) public payable {
        require(_exists(tokenId), "Token does not exist");
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner != address(0), "Invalid token owner");

        uint256 price = _tokenPrices[tokenId];
        require(msg.value >= price, "Insufficient payment");

        uint256 tokenRoyalty = (price * _tokenRoyalties[tokenId]) / 100;
        uint256 amountAfterRoyalty = price - tokenRoyalty;

        payable(tokenOwner).transfer(amountAfterRoyalty); // Send payment to token owner
        payable(_tokenRoyaltyRecipients.get(tokenId)).transfer(tokenRoyalty); // Send royalty fee to recipient

        _transfer(tokenOwner, _msgSender(), tokenId); // Transfer ownership of token

        emit NFTSold(_msgSender(), tokenId, price);
    }

    function setRoyaltyFee(uint256 newRoyaltyFee) public {
        require(msg.sender == owner, "Caller is not the owner");
        royaltyFee = newRoyaltyFee;
    }

    function createAuction(uint256 tokenId, uint256 startingPrice) public {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == _msgSender(), "Caller is not the token owner");

        _tokenPrices[tokenId] = startingPrice;
        _tokenHighestBidder[tokenId] = address(0);
        _tokenHighestBid[tokenId] = 0;
    }

    function placeBid(uint256 tokenId) public payable {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) != _msgSender(), "Token owner cannot bid");
        require(msg.value > _tokenPrices[tokenId], "Bid amount should be higher than current price");

        address previousHighestBidder = _tokenHighestBidder[tokenId];
      
        if (previousHighestBidder != address(0)) {
            payable(previousHighestBidder).transfer(_tokenHighestBid[tokenId]); // Refund the previous highest bidder
        }

        _tokenHighestBidder[tokenId] = _msgSender();
        _tokenHighestBid[tokenId] = msg.value;

        emit NewBid(_msgSender(), tokenId, msg.value);
    }

    function endAuction(uint256 tokenId) public {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == _msgSender(), "Caller is not the token owner");
        require(_tokenHighestBidder[tokenId] != address(0), "No valid bid for this auction");

        address winner = _tokenHighestBidder[tokenId];
        uint256 amount = _tokenHighestBid[tokenId];

        payable(ownerOf(tokenId)).transfer(amount); // Send the winning amount to the token owner
        _transfer(ownerOf(tokenId), winner, tokenId); // Transfer ownership of the token to the winner

        _tokenPrices[tokenId] = 0;
        _tokenHighestBidder[tokenId] = address(0);
        _tokenHighestBid[tokenId] = 0;

        emit AuctionEnded(tokenId, winner, amount);
    }
}