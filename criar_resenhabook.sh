#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="resenhabook"
FORCE=0
INSTALL=1
START=0

usage() {
  cat <<'TXT'
Uso: ./criar_resenhabook.sh [opções]

Opções:
  --dir CAMINHO   Pasta do projeto (padrão: ./resenhabook)
  --force         Permite recriar arquivos dentro de uma pasta existente
  --no-install    Apenas cria os arquivos, sem baixar dependências
  --start         Inicia MongoDB, backend e frontend depois da criação
  -h, --help      Mostra esta ajuda
TXT
}

while (($#)); do
  case "$1" in
    --dir)
      [[ $# -ge 2 ]] || { echo "Falta o caminho após --dir." >&2; exit 2; }
      PROJECT_DIR=$2
      shift 2
      ;;
    --force) FORCE=1; shift ;;
    --no-install) INSTALL=0; shift ;;
    --start) START=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -e "$PROJECT_DIR" && $FORCE -ne 1 ]]; then
  echo "A pasta '$PROJECT_DIR' já existe. Use --force para continuar sem apagar arquivos extras." >&2
  exit 1
fi

if [[ $INSTALL -eq 1 || $START -eq 1 ]]; then
  for command_name in java mvn node npm; do
    command -v "$command_name" >/dev/null 2>&1 || {
      echo "Comando obrigatório não encontrado: $command_name" >&2
      exit 1
    }
  done
fi

mkdir -p "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/"{config,controller,dto,model,repository,service}
mkdir -p "$PROJECT_DIR/backend/src/main/resources"
mkdir -p "$PROJECT_DIR/backend/src/test/java/br/com/resenhabook/backend"
mkdir -p "$PROJECT_DIR/frontend/src/pages"

cat > "$PROJECT_DIR/.gitignore" <<'EOF'
backend/target/
frontend/node_modules/
frontend/dist/
.idea/
.vscode/
*.log
*.pid
EOF

cat > "$PROJECT_DIR/compose.yaml" <<'EOF'
services:
  mongodb:
    image: mongo:7
    container_name: resenhabook-mongodb
    restart: unless-stopped
    ports:
      - "27017:27017"
    volumes:
      - resenhabook_mongo_data:/data/db

volumes:
  resenhabook_mongo_data:
EOF

cat > "$PROJECT_DIR/backend/pom.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.5.6</version>
    <relativePath/>
  </parent>
  <groupId>br.com.resenhabook</groupId>
  <artifactId>backend</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>resenhabook-backend</name>
  <properties>
    <java.version>17</java.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-websocket</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-mongodb</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <optional>true</optional>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
        <configuration>
          <excludes>
            <exclude>
              <groupId>org.projectlombok</groupId>
              <artifactId>lombok</artifactId>
            </exclude>
          </excludes>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
EOF

cat > "$PROJECT_DIR/backend/src/main/resources/application.properties" <<'EOF'
spring.application.name=resenhabook-backend
spring.data.mongodb.uri=${MONGODB_URI:mongodb://localhost:27017/resenhabook}
server.port=${PORT:8080}
spring.jackson.default-property-inclusion=non_null
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/BackendApplication.java" <<'EOF'
package br.com.resenhabook.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class BackendApplication {
    public static void main(String[] args) {
        SpringApplication.run(BackendApplication.class, args);
    }
}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/model/Group.java" <<'EOF'
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
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/model/Conversation.java" <<'EOF'
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
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/model/ChatMessage.java" <<'EOF'
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
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/dto/ChatMessageRequest.java" <<'EOF'
package br.com.resenhabook.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChatMessageRequest(
        @NotBlank @Size(max = 1000) String text,
        @NotBlank @Size(max = 80) String senderName
) {}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/dto/CreateGroupRequest.java" <<'EOF'
package br.com.resenhabook.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Set;

public record CreateGroupRequest(
        @NotBlank @Size(max = 100) String name,
        @Size(max = 500) String description,
        Set<String> memberIds,
        boolean mapEnabled,
        boolean rankingEnabled
) {}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/dto/CreateConversationRequest.java" <<'EOF'
package br.com.resenhabook.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Set;

public record CreateConversationRequest(
        @NotBlank @Size(max = 100) String name,
        @Pattern(regexp = "GROUP|CUSTOM") String visibility,
        @Pattern(regexp = "GROUP|CUSTOM") String postingPermission,
        Set<String> allowedViewerIds,
        Set<String> allowedSenderIds
) {}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/repository/GroupRepository.java" <<'EOF'
package br.com.resenhabook.backend.repository;

import br.com.resenhabook.backend.model.Group;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface GroupRepository extends MongoRepository<Group, String> {
    List<Group> findByMemberIdsContaining(String userId);
}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/repository/ConversationRepository.java" <<'EOF'
package br.com.resenhabook.backend.repository;

import br.com.resenhabook.backend.model.Conversation;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface ConversationRepository extends MongoRepository<Conversation, String> {
    List<Conversation> findByGroupId(String groupId);
}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/repository/MessageRepository.java" <<'EOF'
package br.com.resenhabook.backend.repository;

import br.com.resenhabook.backend.model.ChatMessage;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface MessageRepository extends MongoRepository<ChatMessage, String> {
    List<ChatMessage> findTop50ByConversationIdOrderBySentAtDesc(String conversationId);
}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/service/PermissionService.java" <<'EOF'
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
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/config/WebSocketConfig.java" <<'EOF'
package br.com.resenhabook.backend.config;

import br.com.resenhabook.backend.service.PermissionService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.web.socket.config.annotation.*;
import java.security.Principal;

@Configuration
@EnableWebSocketMessageBroker
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    private final PermissionService permissionService;

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic");
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws").setAllowedOrigins("http://localhost:5173");
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                if (accessor == null) return message;
                if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                    String userId = accessor.getFirstNativeHeader("X-User-Id");
                    if (userId == null || userId.isBlank()) throw new IllegalArgumentException("Usuário não informado.");
                    accessor.setUser(() -> userId);
                }
                if (StompCommand.SUBSCRIBE.equals(accessor.getCommand())) validateSubscription(accessor);
                if (StompCommand.SEND.equals(accessor.getCommand())) validateSend(accessor);
                return message;
            }
        });
    }

    private void validateSubscription(StompHeaderAccessor accessor) {
        String destination = accessor.getDestination();
        Principal principal = accessor.getUser();
        String prefix = "/topic/conversations/";
        if (destination != null && principal != null && destination.startsWith(prefix)) {
            String conversationId = destination.substring(prefix.length());
            if (!permissionService.canView(principal.getName(), conversationId))
                throw new IllegalArgumentException("Sem permissão para visualizar a conversa.");
        }
    }

    private void validateSend(StompHeaderAccessor accessor) {
        String destination = accessor.getDestination();
        Principal principal = accessor.getUser();
        String prefix = "/app/chat.send/";
        if (destination != null && principal != null && destination.startsWith(prefix)) {
            String conversationId = destination.substring(prefix.length());
            if (!permissionService.canSend(principal.getName(), conversationId))
                throw new IllegalArgumentException("Sem permissão para enviar mensagens.");
        }
    }
}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/config/CorsConfig.java" <<'EOF'
package br.com.resenhabook.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.*;

@Configuration
public class CorsConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins("http://localhost:5173")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }
}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/config/DataSeeder.java" <<'EOF'
package br.com.resenhabook.backend.config;

import br.com.resenhabook.backend.model.Conversation;
import br.com.resenhabook.backend.model.Group;
import br.com.resenhabook.backend.repository.ConversationRepository;
import br.com.resenhabook.backend.repository.GroupRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import java.util.HashSet;
import java.util.Set;

@Component
@RequiredArgsConstructor
public class DataSeeder implements CommandLineRunner {
    private final GroupRepository groupRepository;
    private final ConversationRepository conversationRepository;

    @Override
    public void run(String... args) {
        if (!groupRepository.existsById("grupo-demo")) {
            groupRepository.save(Group.builder()
                    .id("grupo-demo").name("Alejandro Systems")
                    .description("Grupo de demonstração do PB03")
                    .ownerId("alejandro")
                    .memberIds(new HashSet<>(Set.of("alejandro", "mauricio", "guilherme")))
                    .mapEnabled(true).rankingEnabled(true).build());
        }
        if (!conversationRepository.existsById("geral")) {
            conversationRepository.save(Conversation.builder()
                    .id("geral").groupId("grupo-demo").name("Geral")
                    .visibility("GROUP").postingPermission("GROUP").build());
        }
    }
}
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/controller/ChatWebSocketController.java" <<'EOF'
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
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/controller/MessageController.java" <<'EOF'
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
EOF

cat > "$PROJECT_DIR/backend/src/main/java/br/com/resenhabook/backend/controller/GroupController.java" <<'EOF'
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
EOF

cat > "$PROJECT_DIR/backend/src/test/java/br/com/resenhabook/backend/PermissionServiceTests.java" <<'EOF'
package br.com.resenhabook.backend;

import br.com.resenhabook.backend.model.Conversation;
import br.com.resenhabook.backend.model.Group;
import br.com.resenhabook.backend.repository.ConversationRepository;
import br.com.resenhabook.backend.repository.GroupRepository;
import br.com.resenhabook.backend.service.PermissionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.util.Optional;
import java.util.Set;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PermissionServiceTests {
    @Mock ConversationRepository conversationRepository;
    @Mock GroupRepository groupRepository;
    PermissionService service;

    @BeforeEach
    void setUp() {
        service = new PermissionService(conversationRepository, groupRepository);
        when(conversationRepository.findById("geral")).thenReturn(Optional.of(
                Conversation.builder().id("geral").groupId("grupo-demo")
                        .visibility("GROUP").postingPermission("GROUP").build()));
        when(groupRepository.findById("grupo-demo")).thenReturn(Optional.of(
                Group.builder().id("grupo-demo").ownerId("alejandro")
                        .memberIds(Set.of("alejandro", "mauricio")).build()));
    }

    @Test
    void memberCanViewAndSend() {
        assertTrue(service.canView("mauricio", "geral"));
        assertTrue(service.canSend("mauricio", "geral"));
    }

    @Test
    void outsiderCannotViewOrSend() {
        assertFalse(service.canView("intruso", "geral"));
        assertFalse(service.canSend("intruso", "geral"));
    }
}
EOF

cat > "$PROJECT_DIR/frontend/package.json" <<'EOF'
{
  "name": "resenhabook-frontend",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@stomp/stompjs": "^7.1.1",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.30.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "vite": "^6.1.0"
  }
}
EOF

cat > "$PROJECT_DIR/frontend/index.html" <<'EOF'
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>ResenhaBook</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

cat > "$PROJECT_DIR/frontend/vite.config.js" <<'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
});
EOF

cat > "$PROJECT_DIR/frontend/src/main.jsx" <<'EOF'
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.jsx";

createRoot(document.getElementById("root")).render(
  <StrictMode><App /></StrictMode>
);
EOF

cat > "$PROJECT_DIR/frontend/src/App.jsx" <<'EOF'
import { BrowserRouter, Route, Routes } from "react-router-dom";
import Home from "./pages/Home";
import ChatPage from "./pages/ChatPage";
import "./styles.css";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/chat" element={<ChatPage />} />
      </Routes>
    </BrowserRouter>
  );
}
EOF

cat > "$PROJECT_DIR/frontend/src/api.js" <<'EOF'
const BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8080/api";

async function request(path, userId, options = {}) {
  const response = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", "X-User-Id": userId, ...(options.headers || {}) },
  });
  if (!response.ok) throw new Error(`Erro HTTP ${response.status}`);
  return response.status === 204 ? null : response.json();
}

export const getGroups = (userId) => request("/groups", userId);
export const getConversations = (groupId, userId) => request(`/groups/${groupId}/conversations`, userId);
export const getMessages = (conversationId, userId) => request(`/conversations/${conversationId}/messages`, userId);
export const createGroup = (userId, data) => request("/groups", userId, { method: "POST", body: JSON.stringify(data) });
export const createConversation = (groupId, userId, data) => request(`/groups/${groupId}/conversations`, userId, { method: "POST", body: JSON.stringify(data) });
EOF

cat > "$PROJECT_DIR/frontend/src/pages/Home.jsx" <<'EOF'
import { Link } from "react-router-dom";

export default function Home() {
  return (
    <main className="home">
      <h1>ResenhaBook</h1>
      <p>Sprint 1 — módulos em desenvolvimento.</p>
      <Link className="pb-link" to="/chat?user=alejandro&name=Alejandro">
        Abrir PB03 — Chat em tempo real
      </Link>
    </main>
  );
}
EOF

cat > "$PROJECT_DIR/frontend/src/pages/ChatPage.jsx" <<'EOF'
import { useEffect, useRef, useState } from "react";
import { Client } from "@stomp/stompjs";
import { useSearchParams } from "react-router-dom";
import { createConversation, createGroup, getConversations, getGroups, getMessages } from "../api";

export default function ChatPage() {
  const [params] = useSearchParams();
  const userId = params.get("user") || "alejandro";
  const userName = params.get("name") || "Alejandro";
  const [groups, setGroups] = useState([]);
  const [group, setGroup] = useState(null);
  const [conversations, setConversations] = useState([]);
  const [conversation, setConversation] = useState(null);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState("");
  const [connected, setConnected] = useState(false);
  const [showSidebar, setShowSidebar] = useState(true);
  const [groupFormOpen, setGroupFormOpen] = useState(false);
  const [conversationFormOpen, setConversationFormOpen] = useState(false);
  const [groupName, setGroupName] = useState("");
  const [memberIds, setMemberIds] = useState("mauricio,guilherme");
  const [conversationName, setConversationName] = useState("");
  const [notice, setNotice] = useState("");
  const clientRef = useRef(null);
  const subscriptionRef = useRef(null);
  const bottomRef = useRef(null);

  function report(message) { setNotice(message); }

  async function loadGroups(selectFirst = true) {
    try {
      const data = await getGroups(userId);
      setGroups(data);
      if (selectFirst && data.length) await selectGroup(data[0]);
    } catch { report("Não foi possível carregar os grupos. Confira se o backend está ativo."); }
  }

  async function selectGroup(selectedGroup) {
    setGroup(selectedGroup);
    setShowSidebar(window.innerWidth > 760);
    try {
      const data = await getConversations(selectedGroup.id, userId);
      setConversations(data);
      setConversation(data[0] || null);
      if (!data.length) setMessages([]);
    } catch { report("Não foi possível carregar as conversas deste grupo."); }
  }

  useEffect(() => { loadGroups(); }, [userId]);

  useEffect(() => {
    if (!conversation) return;
    let cancelled = false;
    getMessages(conversation.id, userId)
      .then((history) => { if (!cancelled) setMessages(history); })
      .catch(() => report("Não foi possível carregar o histórico."));
    connectToConversation(conversation.id);
    return () => {
      cancelled = true;
      subscriptionRef.current?.unsubscribe();
      subscriptionRef.current = null;
    };
  }, [conversation?.id, userId]);

  useEffect(() => () => { clientRef.current?.deactivate(); }, []);
  useEffect(() => bottomRef.current?.scrollIntoView({ behavior: "smooth" }), [messages]);

  function connectToConversation(conversationId) {
    if (clientRef.current?.active) { subscribe(conversationId); return; }
    const client = new Client({
      brokerURL: (import.meta.env.VITE_WS_URL || "ws://localhost:8080/ws"),
      connectHeaders: { "X-User-Id": userId },
      reconnectDelay: 3000,
      onConnect: () => { setConnected(true); subscribe(conversationId); },
      onDisconnect: () => setConnected(false),
      onWebSocketClose: () => setConnected(false),
      onStompError: () => report("Falha na conexão em tempo real."),
    });
    client.activate();
    clientRef.current = client;
  }

  function subscribe(conversationId) {
    subscriptionRef.current?.unsubscribe();
    subscriptionRef.current = clientRef.current.subscribe(`/topic/conversations/${conversationId}`, (frame) => {
      setMessages((current) => [...current, JSON.parse(frame.body)]);
      if (document.hidden) document.title = "Nova mensagem — ResenhaBook";
    });
  }

  function sendMessage(event) {
    event.preventDefault();
    if (!text.trim() || !conversation) return;
    if (!clientRef.current?.connected) { report("A conexão em tempo real ainda não está pronta."); return; }
    clientRef.current.publish({
      destination: `/app/chat.send/${conversation.id}`,
      body: JSON.stringify({ text: text.trim(), senderName: userName }),
    });
    setText("");
    setNotice("");
  }

  async function submitGroup(event) {
    event.preventDefault();
    if (!groupName.trim()) return;
    try {
      await createGroup(userId, {
        name: groupName.trim(), description: "",
        memberIds: memberIds.split(",").map((id) => id.trim()).filter(Boolean),
        mapEnabled: false, rankingEnabled: false,
      });
      setGroupName(""); setGroupFormOpen(false); setNotice("");
      await loadGroups();
    } catch { report("Não foi possível criar o grupo."); }
  }

  async function submitConversation(event) {
    event.preventDefault();
    if (!group || !conversationName.trim()) return;
    try {
      await createConversation(group.id, userId, {
        name: conversationName.trim(), visibility: "GROUP", postingPermission: "GROUP",
        allowedViewerIds: [], allowedSenderIds: [],
      });
      const data = await getConversations(group.id, userId);
      setConversations(data); setConversationName(""); setConversationFormOpen(false); setNotice("");
    } catch { report("Somente o administrador do grupo pode criar conversas."); }
  }

  return (
    <main className="chat-page" onFocus={() => { document.title = "ResenhaBook"; }}>
      <aside className={showSidebar ? "chat-sidebar open" : "chat-sidebar"}>
        <div className="sidebar-header"><strong>ResenhaBook</strong><button onClick={() => setGroupFormOpen(!groupFormOpen)}>+ grupo</button></div>
        {groupFormOpen && (
          <form className="inline-form" onSubmit={submitGroup}>
            <label>Nome<input value={groupName} onChange={(e) => setGroupName(e.target.value)} maxLength="100" required /></label>
            <label>Integrantes (IDs separados por vírgula)<input value={memberIds} onChange={(e) => setMemberIds(e.target.value)} /></label>
            <div><button type="submit">Criar</button><button type="button" className="secondary" onClick={() => setGroupFormOpen(false)}>Cancelar</button></div>
          </form>
        )}
        <p className="sidebar-section">Grupos</p>
        {groups.map((item) => <button key={item.id} className={group?.id === item.id ? "sidebar-item selected" : "sidebar-item"} onClick={() => selectGroup(item)}>{item.name}</button>)}
        {group && <>
          <div className="sidebar-section-row"><span>Conversas</span><button onClick={() => setConversationFormOpen(!conversationFormOpen)}>+</button></div>
          {conversationFormOpen && (
            <form className="inline-form" onSubmit={submitConversation}>
              <label>Nome<input value={conversationName} onChange={(e) => setConversationName(e.target.value)} maxLength="100" required /></label>
              <div><button type="submit">Criar</button><button type="button" className="secondary" onClick={() => setConversationFormOpen(false)}>Cancelar</button></div>
            </form>
          )}
          {conversations.map((item) => <button key={item.id} className={conversation?.id === item.id ? "sidebar-item selected" : "sidebar-item"} onClick={() => { setConversation(item); setShowSidebar(window.innerWidth > 760); }}># {item.name}</button>)}
        </>}
        <div className="demo-user">Usuário: <strong>{userName}</strong></div>
      </aside>

      <section className="chat-panel">
        <header className="chat-header">
          <button className="menu-button" aria-label="Abrir menu" onClick={() => setShowSidebar(!showSidebar)}>☰</button>
          <div className="avatar">{userName.charAt(0)}</div>
          <div><strong>{group?.name || "Selecione um grupo"}</strong><small>{conversation ? `# ${conversation.name}` : "Nenhuma conversa"}</small></div>
          <span className={connected ? "connection online" : "connection offline"}>{connected ? "● online" : "● offline"}</span>
        </header>
        <div className="orange-line" />
        {notice && <div className="notice" role="status"><span>{notice}</span><button onClick={() => setNotice("")} aria-label="Fechar aviso">×</button></div>}
        <div className="messages">
          {!conversation && <div className="empty-chat">Selecione uma conversa.</div>}
          {messages.map((message) => {
            const mine = message.senderId === userId;
            return <div key={message.id} className={mine ? "message-row mine" : "message-row"}>
              <div className={mine ? "bubble bubble-mine" : "bubble bubble-other"}>
                {!mine && <span className="sender">{message.senderName}</span>}
                <span>{message.text}</span>
                <time>{new Date(message.sentAt).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}</time>
              </div>
            </div>;
          })}
          <div ref={bottomRef} />
        </div>
        <form className="message-form" onSubmit={sendMessage}>
          <input type="text" placeholder="Digite..." value={text} disabled={!conversation} onChange={(e) => setText(e.target.value)} maxLength="1000" />
          <button type="submit" disabled={!conversation} title="Enviar">➜</button>
        </form>
      </section>
    </main>
  );
}
EOF

cat > "$PROJECT_DIR/frontend/src/styles.css" <<'EOF'
* { box-sizing: border-box; }
html, body, #root { margin: 0; min-height: 100%; font-family: Arial, Helvetica, sans-serif; }
button, input { font: inherit; }
button { cursor: pointer; }
.home { min-height: 100vh; display: grid; place-content: center; gap: 16px; padding: 24px; text-align: center; background: #f5f5f5; }
.home h1 { margin: 0; }
.pb-link { background: #0874b9; color: white; padding: 14px 22px; border-radius: 12px; text-decoration: none; font-weight: 700; }
.chat-page { height: 100vh; display: flex; overflow: hidden; background: #062131; }
.chat-sidebar { width: 280px; flex-shrink: 0; padding: 18px; overflow-y: auto; background: #071826; color: white; border-right: 1px solid #ffffff1a; }
.sidebar-header, .sidebar-section-row { display: flex; align-items: center; justify-content: space-between; }
.sidebar-header strong { font-size: 22px; }
.sidebar-header button, .sidebar-section-row button, .inline-form button { border: 0; border-radius: 8px; padding: 7px 10px; color: white; background: #0874b9; }
.sidebar-section { margin-top: 30px; opacity: .7; text-transform: uppercase; font-size: 12px; letter-spacing: 1px; }
.sidebar-section-row { margin: 26px 0 8px; font-size: 12px; text-transform: uppercase; opacity: .8; }
.sidebar-item { width: 100%; border: 0; background: transparent; color: #ddd; padding: 11px; border-radius: 8px; text-align: left; margin-bottom: 4px; }
.sidebar-item:hover, .sidebar-item.selected { background: #10354a; color: white; }
.inline-form { margin: 14px 0; padding: 12px; display: grid; gap: 10px; border-radius: 10px; background: #10354a; }
.inline-form label { display: grid; gap: 5px; font-size: 12px; }
.inline-form input { width: 100%; min-width: 0; padding: 8px; border: 0; border-radius: 6px; }
.inline-form div { display: flex; gap: 7px; }
.inline-form .secondary { background: #526776; }
.demo-user { margin-top: 30px; font-size: 13px; color: #aaa; }
.chat-panel { display: flex; flex-direction: column; flex: 1; min-width: 0; height: 100vh; background: #062131; }
.chat-header { min-height: 62px; display: flex; align-items: center; gap: 10px; padding: 10px 18px; background: #0874b9; color: white; }
.chat-header small { display: block; margin-top: 2px; opacity: .75; }
.avatar { width: 36px; height: 36px; display: grid; place-content: center; border: 2px solid white; border-radius: 50%; }
.menu-button { display: none; border: 0; background: transparent; color: white; font-size: 22px; }
.connection { margin-left: auto; font-size: 12px; }
.online { color: #d4ffd9; } .offline { color: #ffd0d0; }
.orange-line { height: 8px; background: #f7a81b; }
.notice { display: flex; justify-content: space-between; align-items: center; gap: 10px; padding: 9px 16px; background: #fff2cc; color: #5b4300; }
.notice button { border: 0; background: transparent; font-size: 20px; }
.messages { flex: 1; overflow-y: auto; padding: 28px 22px; }
.message-row { display: flex; justify-content: flex-start; margin-bottom: 18px; }
.message-row.mine { justify-content: flex-end; }
.bubble { position: relative; max-width: min(70%, 540px); min-width: 120px; border-radius: 18px; padding: 10px 14px 20px; overflow-wrap: anywhere; }
.bubble-other { background: #efefef; color: #111; }
.bubble-mine { background: #0874b9; color: white; }
.sender { display: block; margin-bottom: 3px; color: #d44b55; font-size: 12px; font-weight: 700; }
.bubble time { position: absolute; bottom: 5px; right: 11px; font-size: 9px; opacity: .65; }
.empty-chat { margin: 20px auto; color: #9aabb5; text-align: center; }
.message-form { display: flex; align-items: center; gap: 12px; padding: 10px 14px; background: white; }
.message-form input { flex: 1; min-width: 0; height: 38px; border: 0; outline: 0; border-radius: 999px; padding: 0 18px; background: #dedede; }
.message-form button { width: 48px; height: 38px; border: 0; border-radius: 999px; color: white; background: #0874b9; font-size: 20px; }
.message-form button:disabled { opacity: .4; cursor: default; }
@media (max-width: 760px) {
  .chat-sidebar { position: absolute; z-index: 20; inset: 0 auto 0 0; transform: translateX(-100%); transition: transform .2s; box-shadow: 8px 0 24px #0008; }
  .chat-sidebar.open { transform: translateX(0); }
  .menu-button { display: inline-block; }
  .bubble { max-width: 82%; }
}
EOF

cat > "$PROJECT_DIR/README.md" <<'EOF'
# ResenhaBook — PB03

Projeto React + Spring Boot + MongoDB para chat em grupo em tempo real.

## Executar

1. Inicie o MongoDB: `docker compose up -d`
2. Em outro terminal: `cd backend && mvn spring-boot:run`
3. Em outro terminal: `cd frontend && npm run dev`
4. Abra `http://localhost:5173`

Teste simultâneo:

- `http://localhost:5173/chat?user=alejandro&name=Alejandro`
- `http://localhost:5173/chat?user=mauricio&name=Mauricio`

O cabeçalho `X-User-Id` é apenas uma identidade de demonstração. Quando o PB01
for integrado, ele deve ser substituído pela identidade autenticada do usuário.
EOF

if [[ $INSTALL -eq 1 ]]; then
  echo "Baixando dependências do backend..."
  (cd "$PROJECT_DIR/backend" && mvn -q package)
  echo "Instalando dependências do frontend..."
  (cd "$PROJECT_DIR/frontend" && npm install)
  echo "Validando o frontend..."
  (cd "$PROJECT_DIR/frontend" && npm run build)
fi

echo
echo "Projeto criado em: $PROJECT_DIR"

if [[ $START -eq 1 ]]; then
  command -v docker >/dev/null 2>&1 || { echo "Docker não encontrado; não foi possível iniciar o MongoDB." >&2; exit 1; }
  (cd "$PROJECT_DIR" && docker compose up -d)
  echo "Iniciando backend e frontend. Use Ctrl+C para encerrar os dois."
  (cd "$PROJECT_DIR/backend" && mvn spring-boot:run) &
  BACKEND_PID=$!
  (cd "$PROJECT_DIR/frontend" && npm run dev) &
  FRONTEND_PID=$!
  trap 'kill "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null || true' INT TERM EXIT
  wait
else
  cat <<EOF

Para executar:
  cd "$PROJECT_DIR"
  docker compose up -d

Em outro terminal:
  cd "$PROJECT_DIR/backend" && mvn spring-boot:run

Em outro terminal:
  cd "$PROJECT_DIR/frontend" && npm run dev
EOF
fi
