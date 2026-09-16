package br.com.resenhabook.backend.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import java.time.Instant;

@Document("messages")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatMessage {
    @Id private String id;
    private String groupId;
    private String conversationId;
    private String senderId;
    private String senderName;
    private String text;
    private Instant sentAt;
}
