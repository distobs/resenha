package br.com.resenhabook.backend.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import java.util.HashSet;
import java.util.Set;

@Document("groups")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Group {
    @Id private String id;
    private String name;
    private String description;
    private String ownerId;
    @Builder.Default private Set<String> memberIds = new HashSet<>();
    private boolean mapEnabled;
    private boolean rankingEnabled;
}
