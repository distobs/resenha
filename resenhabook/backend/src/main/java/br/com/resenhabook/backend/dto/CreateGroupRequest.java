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
