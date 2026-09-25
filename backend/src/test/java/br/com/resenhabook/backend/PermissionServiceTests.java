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
