package br.com.resenhabook.backend.repository;

import br.com.resenhabook.backend.model.Conversation;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface ConversationRepository extends MongoRepository<Conversation, String> {
    List<Conversation> findByGroupId(String groupId);
}
