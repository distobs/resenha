package br.com.resenhabook.backend.controller;

import br.com.resenhabook.backend.dto.ChatMessageRequest;
import br.com.resenhabook.backend.model.ChatMessage;
import br.com.resenhabook.backend.model.Conversation;
import br.com.resenhabook.backend.repository.ConversationRepository;
import br.com.resenhabook.backend.repository.MessageRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.*;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;
import java.security.Principal;
import java.time.Instant;

@Controller
@RequiredArgsConstructor
public class ChatWebSocketController {
    private final MessageRepository messageRepository;
    private final ConversationRepository conversationRepository;
    private final SimpMessagingTemplate messagingTemplate;

    @MessageMapping("/chat.send/{conversationId}")
    public void send(@DestinationVariable String conversationId,
                     @Valid ChatMessageRequest request,
                     Principal principal) {
        Conversation conversation = conversationRepository.findById(conversationId).orElseThrow();
        ChatMessage saved = messageRepository.save(ChatMessage.builder()
                .groupId(conversation.getGroupId()).conversationId(conversationId)
                .senderId(principal.getName()).senderName(request.senderName())
                .text(request.text().trim()).sentAt(Instant.now()).build());
        messagingTemplate.convertAndSend("/topic/conversations/" + conversationId, saved);
    }
}
