#include "http_socket.h"

#include <stdbool.h>

#include <lwip/ip.h>
#include <lwip/pbuf.h>
#include <lwip/tcp.h>

const char *http_error_msg =
"HTTP/1.0 404 Not Found\n"
"Content-Type: text/html; charset=UTF-8\n"
"\n"
"<h1>404 Page not found</h1>\n\n";

const char *http_template_msg =
"HTTP/1.0 200 OK\n"
"Content-Type: text/html; charset=UTF-8\n"
"\n"
"<h1>%s</h1>\n";

#define MAX_CONCURRENT_CONNECTIONS 4

typedef struct
{
    bool in_use;

    struct pbuf *req;
} http_socket_state;

http_socket_state socket_state_pool[MAX_CONCURRENT_CONNECTIONS];
static http_socket_state *allocate_socket_state()
{
    for (int i = 0; i < MAX_CONCURRENT_CONNECTIONS; i++) {
        if (socket_state_pool[i].in_use == false) {
            return &socket_state_pool[i];
        }
    }

    return NULL;
}

static void free_socket_state(http_socket_state *state)
{
    state->in_use = false;
}

static void http_error_callback(void *arg, err_t err)
{
    http_socket_state *state = arg;
    free_socket_state(state);
}

static err_t http_sent_callback(void *arg, struct tcp_pcb *pcb, u16_t len)
{
    tcp_recved(pcb, len);
    return ERR_OK;
}

static err_t http_recv_callback(void *arg,
                               struct tcp_pcb *pcb,
                               struct pbuf *p,
                               err_t err)
{
    http_socket_state *state = arg;

    sddf_printf("WEBSERVER|HTTP: recv_callback with %u bytes with error %s\n", p->tot_len, lwip_strerr(err));

    // Nothing arrived, should close socket
    if (p == NULL) {
        free_socket_state(state);
        tcp_arg(pcb, NULL);

        err = tcp_close(pcb);
        if (err) {
            sddf_printf("WEBSERVER|CLOSE[%s:%d]: could not close connection\n",
                        ipaddr_ntoa(&pcb->remote_ip), pcb->remote_port);
            return err;
        }
    }

    if (err) {
        sddf_printf("WEBSERVER|RECV[%s:%d]: recv error: %s\n",
                    ipaddr_ntoa(&pcb->remote_ip),
                    pcb->remote_port,
                    lwip_strerr(err));
        return err;
    }

    char *payload = p->payload;
    sddf_printf("%s\n", payload);
    if (payload[0] == 'G' && payload[1] == 'E' && payload[2] == 'T') {
        err = tcp_write(pcb, http_template_msg, sddf_strlen(http_template_msg), 0);
        tcp_output(pcb);
    } else {
        err = tcp_write(pcb, http_error_msg, sddf_strlen(http_error_msg), 0);
        tcp_output(pcb);
    }

    tcp_recved(pcb, p->len);

    free_socket_state(state);
    tcp_arg(pcb, NULL);
    tcp_close(pcb);

    return ERR_OK;
}

static err_t http_accept_callback(void *arg, struct tcp_pcb *pcb, err_t err)
{
    http_socket_state *state = allocate_socket_state();
    if (state == NULL) {
        sddf_printf("WEBSERVER|ACCEPT: too much connections\n");
        return ERR_MEM;
    }

    sddf_printf("WEBSERVER|ACCEPT[%s:%d]: connection accepted\n",
        ipaddr_ntoa(&pcb->remote_ip), pcb->remote_port);

    tcp_nagle_disable(pcb);
    tcp_arg(pcb, state);
    tcp_sent(pcb, http_sent_callback);
    tcp_recv(pcb, http_recv_callback);
    tcp_err(pcb, http_error_callback);

    return ERR_OK;
}


void http_socket_setup()
{
    for (int i = 0; i < MAX_CONCURRENT_CONNECTIONS; i++) {
        socket_state_pool[i].in_use = false;
    }

    struct tcp_pcb *pcb = tcp_new_ip_type(IPADDR_TYPE_V4);
    if (pcb == NULL) {
        sddf_printf("WEBSERVER: could not create http socket\n");
        return;
    }

    err_t error = tcp_bind(pcb, IP_ANY_TYPE, 80);
    if (error) {
        sddf_printf("WEBSERVER: could not bind http socket: %s\n",
                    lwip_strerr(error));
        return;
    }

    pcb = tcp_listen_with_backlog_and_err(pcb, 1, &error);
    if (error) {
        sddf_printf("WEBSERVER: could not listen on http socket: %s\n",
                    lwip_strerr(error));
    }

    tcp_accept(pcb, http_accept_callback);
}
