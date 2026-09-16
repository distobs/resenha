package br.com.resenhabook.backend.service;

import br.com.resenhabook.backend.model.Conversation;
import br.com.resenhabook.backend.model.Group;
import br.com.resenhabook.backend.repository.ConversationRepository;
import br.com.resenhabook.backend.repository.GroupRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class PermissionService {
    private final ConversationRepository conversationRepository;
    private final GroupRepository groupRepository;

    public boolean canView(String userId, String conversationId) {
        Conversation conversation = conversationRepository.findById(conversationId).orElse(null);
        if (conversation == null) return false;
        Group group = groupRepository.findById(conversation.getGroupId()).orElse(null);
        if (group == null || !group.getMemberIds().contains(userId)) return false;
        if ("GROUP".equals(conversation.getVisibility())) return true;
        return conversation.getAllowedViewerIds().contains(userId)
                || group.getOwnerId().equals(userId);
    }

    public boolean canSend(String userId, String conversationId) {
        if (!canView(userId, conversationId)) return false;
        Conversation conversation = conversationRepository.findById(conversationId).orElseThrow();
        Group group = groupRepository.findById(conversation.getGroupId()).orElseThrow();
        if ("GROUP".equals(conversation.getPostingPermission())) return true;
        return conversation.getAllowedSenderIds().contains(userId)
                || group.getOwnerId().equals(userId);
    }
}
