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
