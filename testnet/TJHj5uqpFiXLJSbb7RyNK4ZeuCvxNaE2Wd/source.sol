pragma solidity ^0.4.25;

contract PlacePosts{
    mapping(address=>string) internal userPosts;
    event AddedPost(string postId, address indexed member);
    function addPost(string postId) public {
        userPosts[msg.sender] = postId;
        emit AddedPost(postId, msg.sender);
    }
}