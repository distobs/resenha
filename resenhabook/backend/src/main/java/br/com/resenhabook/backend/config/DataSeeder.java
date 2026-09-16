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
