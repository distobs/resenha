package br.com.resenhabook.backend.controller;

import br.com.resenhabook.backend.dto.*;
import br.com.resenhabook.backend.model.Conversation;
import br.com.resenhabook.backend.model.Group;
import br.com.resenhabook.backend.repository.ConversationRepository;
import br.com.resenhabook.backend.repository.GroupRepository;
import br.com.resenhabook.backend.service.PermissionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.util.HashSet;
import java.util.List;

@RestController
@RequestMapping("/api/groups")
@RequiredArgsConstructor
public class GroupController {
    private final GroupRepository groupRepository;
    private final ConversationRepository conversationRepository;
    private final PermissionService permissionService;

    @GetMapping
    public List<Group> groups(@RequestHeader("X-User-Id") String userId) {
        return groupRepository.findByMemberIdsContaining(userId);
    }

    @PostMapping
    public Group createGroup(@RequestHeader("X-User-Id") String userId,
                             @Valid @RequestBody CreateGroupRequest request) {
        HashSet<String> members = new HashSet<>();
        if (request.memberIds() != null) members.addAll(request.memberIds());
        members.add(userId);
        return groupRepository.save(Group.builder()
                .name(request.name().trim()).description(request.description())
                .ownerId(userId).memberIds(members)
                .mapEnabled(request.mapEnabled()).rankingEnabled(request.rankingEnabled()).build());
    }

    @GetMapping("/{groupId}/conversations")
    public ResponseEntity<List<Conversation>> conversations(@PathVariable String groupId,
                                                             @RequestHeader("X-User-Id") String userId) {
        Group group = groupRepository.findById(groupId).orElse(null);
        if (group == null) return ResponseEntity.notFound().build();
        if (!group.getMemberIds().contains(userId)) return ResponseEntity.status(403).build();
        return ResponseEntity.ok(conversationRepository.findByGroupId(groupId).stream()
                .filter(c -> permissionService.canView(userId, c.getId())).toList());
    }

    @PostMapping("/{groupId}/conversations")
    public ResponseEntity<Conversation> createConversation(@PathVariable String groupId,
                                                            @RequestHeader("X-User-Id") String userId,
                                                            @Valid @RequestBody CreateConversationRequest request) {
        Group group = groupRepository.findById(groupId).orElse(null);
        if (group == null) return ResponseEntity.notFound().build();
        if (!group.getOwnerId().equals(userId)) return ResponseEntity.status(403).build();
        Conversation conversation = Conversation.builder()
                .groupId(groupId).name(request.name().trim())
                .visibility(request.visibility() == null ? "GROUP" : request.visibility())
                .postingPermission(request.postingPermission() == null ? "GROUP" : request.postingPermission())
                .allowedViewerIds(request.allowedViewerIds() == null ? new HashSet<>() : new HashSet<>(request.allowedViewerIds()))
                .allowedSenderIds(request.allowedSenderIds() == null ? new HashSet<>() : new HashSet<>(request.allowedSenderIds()))
                .build();
        return ResponseEntity.status(HttpStatus.CREATED).body(conversationRepository.save(conversation));
    }

    @PostMapping("/{groupId}/members/{memberId}")
    public ResponseEntity<Group> addMember(@PathVariable String groupId, @PathVariable String memberId,
                                            @RequestHeader("X-User-Id") String userId) {
        Group group = groupRepository.findById(groupId).orElse(null);
        if (group == null) return ResponseEntity.notFound().build();
        if (!group.getOwnerId().equals(userId)) return ResponseEntity.status(403).build();
        group.getMemberIds().add(memberId);
        return ResponseEntity.ok(groupRepository.save(group));
    }

    @DeleteMapping("/{groupId}/members/{memberId}")
    public ResponseEntity<Void> removeMember(@PathVariable String groupId, @PathVariable String memberId,
                                              @RequestHeader("X-User-Id") String userId) {
        Group group = groupRepository.findById(groupId).orElse(null);
        if (group == null) return ResponseEntity.notFound().build();
        if (!group.getOwnerId().equals(userId) && !memberId.equals(userId)) return ResponseEntity.status(403).build();
        if (memberId.equals(group.getOwnerId())) return ResponseEntity.badRequest().build();
        group.getMemberIds().remove(memberId);
        groupRepository.save(group);
        return ResponseEntity.noContent().build();
    }
}
