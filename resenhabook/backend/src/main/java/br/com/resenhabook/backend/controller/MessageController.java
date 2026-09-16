package br.com.resenhabook.backend.controller;

import br.com.resenhabook.backend.model.ChatMessage;
import br.com.resenhabook.backend.repository.MessageRepository;
import br.com.resenhabook.backend.service.PermissionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@RestController
@RequestMapping("/api/conversations")
@RequiredArgsConstructor
public class MessageController {
    private final MessageRepository messageRepository;
    private final PermissionService permissionService;

    @GetMapping("/{conversationId}/messages")
    public ResponseEntity<List<ChatMessage>> history(@PathVariable String conversationId,
                                                      @RequestHeader("X-User-Id") String userId) {
        if (!permissionService.canView(userId, conversationId)) return ResponseEntity.status(403).build();
        List<ChatMessage> messages = new ArrayList<>(
                messageRepository.findTop50ByConversationIdOrderBySentAtDesc(conversationId));
        Collections.reverse(messages);
        return ResponseEntity.ok(messages);
    }
}
