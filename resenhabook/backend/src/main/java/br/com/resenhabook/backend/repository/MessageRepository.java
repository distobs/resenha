package br.com.resenhabook.backend.repository;

import br.com.resenhabook.backend.model.ChatMessage;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface MessageRepository extends MongoRepository<ChatMessage, String> {
    List<ChatMessage> findTop50ByConversationIdOrderBySentAtDesc(String conversationId);
}
