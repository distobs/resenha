package br.com.resenhabook.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChatMessageRequest(
        @NotBlank @Size(max = 1000) String text,
        @NotBlank @Size(max = 80) String senderName
) {}
