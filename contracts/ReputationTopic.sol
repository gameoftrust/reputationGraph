// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ReputationTopic is ERC721, ERC721URIStorage {
    using Counters for Counters.Counter;

    mapping(uint256 => string) public tokenTitle; // (topicId => title)
    mapping(uint256 => bool) public isFinalized; // (topicId => is finalized)

    Counters.Counter private _tokenIdCounter;

    event titleUpdated(string old_, string new_);
    event Finalized(uint256 tokenId);

    constructor() ERC721("Reputation Topic", "TRT") {}

    function safeMint(
        address to,
        string memory title,
        string memory uri
    ) external {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        tokenTitle[tokenId] = title;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function setTokenURI(
        uint256 tokenId,
        string memory uri
    ) external onlyOwnerOrApproved(tokenId) {
        _setTokenURI(tokenId, uri);
    }

    function setTitle(
        uint256 tokenId,
        string memory title
    ) external notFinalized(tokenId) onlyOwnerOrApproved(tokenId) {
        emit titleUpdated(tokenTitle[tokenId], title);
        tokenTitle[tokenId] = title;
    }

    function finalize(
        uint256 tokenId
    ) external notFinalized(tokenId) onlyOwnerOrApproved(tokenId) {
        isFinalized[tokenId] = true;
        emit Finalized(tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    modifier onlyOwnerOrApproved(uint256 tokenId) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ReputationTopic: Only Owner Or Approved"
        );
        _;
    }

    modifier notFinalized(uint256 tokenId) {
        require(
            isFinalized[tokenId] == false,
            "ReputationTopic: Only Not Finalized"
        );
        _;
    }
}
