// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract ReputationGraph is AccessControl {
    // ================ STATE VARIABLES ==============

    bytes32 public constant ENDORSER_ROLE = keccak256("ENDORSER_ROLE");

    string public metadataURI;
    address public graphId;

    /// @dev used for function argument
    struct Endorsement {
        uint256 timestamp;
        address from;
        address to;
        address graphId;
        RawScore[] scores;
    }

    /// @dev used only in Endorsement struct
    struct RawScore {
        uint256 topicId;
        int8 score;
        uint8 confidence;
    }

    struct Score {
        uint256 timestamp;
        address from;
        address to;
        uint256 topicId;
        int8 score;
        uint8 confidence;
    }

    bytes32 public constant ENDORSEMENT_TYPE_HASH =
        keccak256(
            "Endorsement(uint256 timestamp,address from,address to,address graphId,RawScore[] scores)RawScore(uint256 topicId,int8 score,uint8 confidence)"
        );

    bytes32 public constant RAW_SCORE_TYPE_HASH =
        keccak256("RawScore(uint256 topicId,int8 score,uint8 confidence)");

    bytes32 public constant DOMAIN_SEPARATOR =
        keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version)"),
                keccak256(bytes("Game of Trust")),
                keccak256(bytes("1"))
            )
        );

    mapping(address => uint256) public lastEndorseTimestamp; // address => last endorsement timestamp

    Score[] public scores;

    // ================ ERRORS ==============

    error NotSigner();
    error InvalidGraphId();
    error InvalidTimestamp();

    // ================ EVENTS ==============

    event Scored(
        uint256 timestamp,
        address from,
        address to,
        uint256 questionId,
        int8 score,
        uint8 confidence
    );
    event MetadataUpdated(string _new, string old);

    constructor(address admin, address endorser) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(ENDORSER_ROLE, endorser);
        graphId = msg.sender;
    }

    // ================ PUBLIC VIEWS ==============

    /// @notice returns the length of scores array
    /// @return length
    function getScoresLength() external view returns (uint256) {
        return scores.length;
    }

    /// @notice gets a slice of the scores array
    /// @param fromIndex start index of slice (inclusive)
    /// @param toIndex end index of slice (inclusive)
    /// @return scores the sliced list
    function getScores(
        uint256 fromIndex,
        uint256 toIndex
    ) external view returns (Score[] memory) {
        Score[] memory _scores = new Score[](toIndex - fromIndex + 1);
        for (uint256 i = fromIndex; i <= toIndex; i++) {
            _scores[i - fromIndex] = (scores[i]);
        }
        return _scores;
    }

    /// @notice submit a score using an EIP712 signature from the sender of the score
    /// which is the "from" field of the "score" object passed to this function
    /// @param endorsement score object according to Score struct
    /// @param signature a signature on the score object from the sender
    function endorse(
        Endorsement memory endorsement,
        bytes memory signature
    ) external onlyRole(ENDORSER_ROLE) {
        if (endorsement.graphId != graphId)
            revert InvalidGraphId();
        if (_getSigner(endorsement, signature) != endorsement.from)
            revert NotSigner();
        _endorse(endorsement);
    }

    // ================ RESTRICTED FUNCTIONS ==============

    /// @notice set metadata uri
    /// @param uri uri address
    function setMetadataURI(
        string memory uri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit MetadataUpdated(uri, metadataURI);
        metadataURI = uri;
    }

    // ================ INTERNAL FUNCTIONS ==============

    /// @notice saves the score object from endorsement
    /// @dev the event emitted is intended to be read off-chain to create a graph of scores
    /// @param endorsement score object
    function _endorse(Endorsement memory endorsement) internal {
        address _from = endorsement.from;
        address _to = endorsement.to;
        uint256 _timestamp = endorsement.timestamp;

        if (lastEndorseTimestamp[_from] >= _timestamp)
            revert InvalidTimestamp();
        lastEndorseTimestamp[_from] = _timestamp;

        for (uint8 i = 0; i < endorsement.scores.length; i++) {
            RawScore memory rawScore = endorsement.scores[i];
            scores.push(
                Score(
                    _timestamp,
                    _from,
                    _to,
                    rawScore.topicId,
                    rawScore.score,
                    rawScore.confidence
                )
            );
            emit Scored(
                _timestamp,
                _from,
                _to,
                rawScore.topicId,
                rawScore.score,
                rawScore.confidence
            );
        }
    }

    /// @notice hashes RawScore object
    /// @param rawScore rawScore object
    /// @return hash struct hash of RawScore object
    function hash(RawScore memory rawScore) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    RAW_SCORE_TYPE_HASH,
                    rawScore.topicId,
                    rawScore.score,
                    rawScore.confidence
                )
            );
    }

    /// @notice hashes RawScores array objects
    /// @param rawScores rawScore object
    /// @return hash array struct hash of RawScore object
    function hash(RawScore[] memory rawScores) internal pure returns (bytes32) {
        bytes memory _hash;
        for (uint8 i = 0; i < rawScores.length; i++)
            _hash = abi.encodePacked(_hash, hash(rawScores[i]));
        return keccak256(_hash);
    }

    /// @notice hashes Endorsement array object
    /// @param endorsement endorsement object
    /// @return hash struct hash of Endorsement object
    function hash(
        Endorsement memory endorsement
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ENDORSEMENT_TYPE_HASH,
                    endorsement.timestamp,
                    endorsement.from,
                    endorsement.to,
                    endorsement.graphId,
                    hash(endorsement.scores)
                )
            );
    }

    /// @notice calculates hash digest of Endorsement object for EIP-712 signature verification
    /// @param endorsement Endorsement object
    /// @return digest hash digest
    function digest(
        Endorsement memory endorsement
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    hash(endorsement)
                )
            );
    }

    /// @notice given a hex signature it extracts its r, s and v components
    /// @param sig bytes of the signature
    /// @return r
    /// @return s
    /// @return v
    function _splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    /// @notice recovers the signer of the Endorsement object from it's signature according to EIP-712 standard
    /// @param endorsement Endorsement object
    /// @param sig signature
    /// @return singer
    function _getSigner(
        Endorsement memory endorsement,
        bytes memory sig
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(sig);
        return ecrecover(digest(endorsement), v, r, s);
    }
}
