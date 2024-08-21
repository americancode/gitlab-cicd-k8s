FROM dtzar/helm-kubectl:3.15.4

RUN helm plugin install https://github.com/databus23/helm-diff

CMD ["bash"]