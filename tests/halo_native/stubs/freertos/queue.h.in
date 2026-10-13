#pragma once
#include <stddef.h>
typedef struct test_queue *QueueHandle_t;
QueueHandle_t xQueueCreate(unsigned capacity, size_t size);
int xQueueReceive(QueueHandle_t queue, void *out, unsigned timeout);
int xQueueSend(QueueHandle_t queue, const void *value, unsigned timeout);
