package br.com.resenhabook.backend.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import java.util.HashSet;
import java.util.Set;

@Document("conversations")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Conversation {
    @Id private String id;
    private String groupId;
    private String name;
    private String visibility;
    private String postingPermission;
    @Builder.Default private Set<String> allowedViewerIds = new HashSet<>();
    @Builder.Default private Set<String> allowedSenderIds = new HashSet<>();
}
