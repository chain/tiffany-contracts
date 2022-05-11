// SPDX-License-Identifier: Unlicense

// @title: NFTiff
// @author: Tiffany Team

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "hardhat/console.sol";

contract NFTiff is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using ECDSA for bytes32;
    string private baseURI;
    string public baseExtension = ".json";
    string public notRevealedUri;
    uint256 public cost = 30 ether;
    uint256 public maxSupply = 500;
    uint256 public maxMintAmount = 2;
    bool public presaleActive = false;
    bool public publicSaleActive = false;
    bool public paused = false;
    bool public revealed = false;
    bool public isKycRequired = true;
    address public signer; // signer to make signature
    mapping(address => bool) whitelistedAddresses;
    mapping(address => bool) blacklistedAddresses;

    constructor(string memory _initNotRevealedUri) ERC721("NFTiff", "NFTiff") {
        setNotRevealedURI(_initNotRevealedUri);
        signer = msg.sender;
    }
    
    //MODIFIERS
    modifier notPaused {
         require(!paused, "the contract is paused");
         _;
    }

    modifier notBlacklisted(address user_) {
         require(!blacklistedAddresses[user_], "user in blacklist");
         _;
    }

    // INTERNAL
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function presaleValidations(bytes memory _signature) internal view {
        require(isWhitelisted(msg.sender), "user is not whitelisted");

        if(isKycRequired) {
            bytes32 hash = keccak256(abi.encodePacked("kyc approved", msg.sender));
            address signer_ = hash.toEthSignedMessageHash().recover(_signature);
            require(signer_ == signer, "Kyc not approved");
        }
    }

    //MINT
    function mint1(uint256 _mintAmount, bytes memory _signature) public payable notPaused nonReentrant notBlacklisted(msg.sender) {
        require(presaleActive, "Sale has not started yet");
        require(msg.value >= cost * _mintAmount, "insufficient funds");
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(_mintAmount <= maxMintAmount,"max mint amount per transaction exceeded");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        presaleValidations(_signature);

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }
    
    function gift(uint256 _mintAmount, address destination) public onlyOwner {
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(destination, supply + i);
        }
    }

    //MINT Public
    function mintPublic(uint256 _mintAmount) public payable notPaused nonReentrant notBlacklisted(msg.sender) {
        require(publicSaleActive, "Sale has not started yet");
        require(msg.value >= cost * _mintAmount, "insufficient funds");
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(_mintAmount <= maxMintAmount,"max mint amount per transaction exceeded");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    //PUBLIC VIEWS
    function isWhitelisted(address _user) public view returns (bool) {
        return whitelistedAddresses[_user];
    }

    function isBlacklisted(address _user) public view returns (bool) {
        return blacklistedAddresses[_user];
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (!revealed) {
            return notRevealedUri;
        } else {
            string memory currentBaseURI = _baseURI();
            return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI,tokenId.toString(), baseExtension)) : "";
        }
    }

    //ONLY OWNER VIEWS
    function getBaseURI() public view onlyOwner returns (string memory) {
        return baseURI;
    }

    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function getSigner() public view onlyOwner returns (address) {
        return signer;
    }

    //ONLY OWNER SETTERS
    function reveal() public onlyOwner {
        revealed = true;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

    function setPresaleStatus(bool _saleActive) public onlyOwner {
        presaleActive = _saleActive;
    }

    function setPublicSaleStatus(bool _saleActive) public onlyOwner {
        publicSaleActive = _saleActive;
    }

    function setKycRequired(bool _required) public onlyOwner {
        isKycRequired = _required;
    }

    function setSigner(address signer_) public onlyOwner {
        signer = signer_;
    }

    function whitelistUsers(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelistedAddresses[addresses[i]] = true;
        }
    }

    function blacklistUsers(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklistedAddresses[addresses[i]] = true;
        }
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
}