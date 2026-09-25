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
